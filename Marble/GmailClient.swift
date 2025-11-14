//
//  GmailClient.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation
import AuthenticationServices
import UIKit

final class GmailClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let clientID: String
    private let redirectURI: String
    private let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private let messagesEndpoint = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
    private let messageEndpointBase = "https://gmail.googleapis.com/gmail/v1/users/me/messages/"
    private let modifyEndpoint = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/batchModify")!

    private var authenticationSession: ASWebAuthenticationSession?

    init(clientID: String, redirectURI: String) {
        self.clientID = clientID
        self.redirectURI = redirectURI
    }

    // MARK: - Authorization

    func authorize() async throws -> GmailConfiguration {
        let expectedState = UUID().uuidString
        guard let authURL = authorizationURL(state: expectedState),
              let callbackScheme = URL(string: redirectURI)?.scheme else {
            throw NewsletterError.requestFailed("Invalid OAuth configuration")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { [weak self] url, error in
                defer { self?.authenticationSession = nil }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url,
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                      let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
                      state == expectedState else {
                    continuation.resume(throwing: NewsletterError.requestFailed("Missing authorization code"))
                    return
                }

                Task {
                    guard let self else {
                        continuation.resume(throwing: NewsletterError.requestFailed("Authentication cancelled"))
                        return
                    }

                    do {
                        let configuration = try await self.exchangeAuthorizationCode(code: code)
                        continuation.resume(returning: configuration)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            authenticationSession = session
            if !session.start() {
                continuation.resume(throwing: NewsletterError.requestFailed("Unable to start authentication"))
            }
        }
    }

    func refreshToken(_ configuration: GmailConfiguration) async throws -> GmailConfiguration {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let parameters = [
            "client_id=\(clientID)",
            "grant_type=refresh_token",
            "refresh_token=\(configuration.refreshToken)"
        ].joined(separator: "&")
        request.httpBody = parameters.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsletterError.requestFailed("Token refresh failed")
        }

        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiration = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        return GmailConfiguration(accessToken: token.accessToken, refreshToken: configuration.refreshToken, expirationDate: expiration, userEmail: configuration.userEmail)
    }

    private func exchangeAuthorizationCode(code: String) async throws -> GmailConfiguration {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let parameters = [
            "code=\(code)",
            "client_id=\(clientID)",
            "redirect_uri=\(redirectURI)",
            "grant_type=authorization_code"
        ].joined(separator: "&")
        request.httpBody = parameters.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsletterError.requestFailed("Authorization exchange failed")
        }

        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiration = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        guard let refreshToken = token.refreshToken else {
            throw NewsletterError.requestFailed("Google did not return a refresh token. Ensure offline access is enabled in your OAuth client.")
        }
        let profile = try await fetchProfile(accessToken: token.accessToken)
        return GmailConfiguration(accessToken: token.accessToken, refreshToken: refreshToken, expirationDate: expiration, userEmail: profile.email)
    }

    private func fetchProfile(accessToken: String) async throws -> GmailProfile {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsletterError.requestFailed("Profile fetch failed")
        }
        return try JSONDecoder().decode(GmailProfile.self, from: data)
    }

    // MARK: - Messages

    func fetchMessages(configuration: GmailConfiguration, pageToken: String? = nil) async throws -> GmailListResponse {
        var components = URLComponents(url: messagesEndpoint, resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: "newer_than:30d"),
            URLQueryItem(name: "labelIds", value: "CATEGORY_PROMOTIONS"),
            URLQueryItem(name: "maxResults", value: "50"),
            URLQueryItem(name: "includeSpamTrash", value: "false")
        ]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.addValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsletterError.requestFailed("Unable to fetch messages")
        }
        return try JSONDecoder().decode(GmailListResponse.self, from: data)
    }

    func fetchMessage(id: String, configuration: GmailConfiguration) async throws -> GmailMessageResponse {
        guard let url = URL(string: messageEndpointBase + id + "?format=full") else {
            throw NewsletterError.requestFailed("Invalid message identifier")
        }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsletterError.requestFailed("Unable to fetch message details")
        }
        return try JSONDecoder().decode(GmailMessageResponse.self, from: data)
    }

    func archiveMessage(id: String, configuration: GmailConfiguration) async throws {
        var request = URLRequest(url: modifyEndpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = GmailModifyPayload(ids: [id], removeLabelIds: ["INBOX"], addLabelIds: [])
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsletterError.requestFailed("Failed to archive message")
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    private func authorizationURL(state: String) -> URL? {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/gmail.modify profile email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components?.url
    }
}

// MARK: - DTOs

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct GmailProfile: Decodable {
    let email: String

    private enum CodingKeys: String, CodingKey {
        case email
    }
}

struct GmailListResponse: Decodable {
    struct Item: Decodable {
        let id: String
    }

    let messages: [Item]
    let nextPageToken: String?

    init(messages: [Item], nextPageToken: String?) {
        self.messages = messages
        self.nextPageToken = nextPageToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let messages = try container.decodeIfPresent([Item].self, forKey: .messages) ?? []
        let nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
        self.init(messages: messages, nextPageToken: nextPageToken)
    }

    private enum CodingKeys: String, CodingKey {
        case messages
        case nextPageToken
    }
}

struct GmailMessageResponse: Decodable {
    struct Payload: Decodable {
        struct Part: Decodable {
            let mimeType: String?
            let body: Body?
            let parts: [Part]?
        }

        let headers: [Header]
        let body: Body?
        let parts: [Part]?
    }

    struct Header: Decodable {
        let name: String
        let value: String
    }

    struct Body: Decodable {
        let size: Int
        let data: String?
    }

    let id: String
    let snippet: String
    let internalDate: String
    let payload: Payload
}

private struct GmailModifyPayload: Encodable {
    let ids: [String]
    let removeLabelIds: [String]
    let addLabelIds: [String]
}
