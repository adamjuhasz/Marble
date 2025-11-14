//
//  NewsletterStore.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation

@MainActor
final class NewsletterStore: ObservableObject {
    @Published private(set) var newsletters: [Newsletter] = []
    @Published private(set) var state: LoadingState = .idle
    @Published var errorMessage: String?

    enum LoadingState {
        case idle
        case loading
        case refreshing
    }

    private let configurationStore: ConfigurationStore
    private let gmailClient: GmailClient
    private let openAIClient: OpenAIClient
    private let cache = NewsletterCache()
    private let hasOAuthConfiguration: Bool
    init(configurationStore: ConfigurationStore) {
        self.configurationStore = configurationStore
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
        let redirectURI = Bundle.main.object(forInfoDictionaryKey: "GoogleRedirectURI") as? String ?? ""
        self.gmailClient = GmailClient(clientID: clientID, redirectURI: redirectURI)
        self.hasOAuthConfiguration = !clientID.isEmpty && !redirectURI.isEmpty
        self.openAIClient = OpenAIClient()
        loadPersistedNewsletters()
    }

    func loadNewsletters(force: Bool = false) async {
        guard configurationStore.gmailConfiguration.isAuthorized else {
            errorMessage = nil
            return
        }
        guard !configurationStore.openAIAPIKey.isEmpty else {
            errorMessage = "Add your OpenAI API key in Settings to enable newsletter detection."
            return
        }

        if state == .loading && !force { return }
        state = force ? .refreshing : .loading

        do {
            var configuration = configurationStore.gmailConfiguration
            if configuration.needsRefresh {
                configuration = try await gmailClient.refreshToken(configuration)
                configurationStore.gmailConfiguration = configuration
            }

            let response = try await gmailClient.fetchMessages(configuration: configuration)
            var fetched: [Newsletter] = []

            for item in response.messages {
                do {
                    let message = try await gmailClient.fetchMessage(id: item.id, configuration: configuration)
                    if try await shouldDisplay(message: message) {
                        let newsletter = try await makeNewsletter(from: message)
                        fetched.append(newsletter)
                    }
                } catch {
                    print("Skipping message due to error: \(error)")
                }
            }

            newsletters = merge(existing: newsletters, with: fetched)
            persist()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        state = .idle
    }

    func authorizeGmail() async {
        guard hasOAuthConfiguration else {
            errorMessage = "Set GoogleClientID and GoogleRedirectURI in Info.plist before connecting Gmail."
            return
        }
        do {
            let configuration = try await gmailClient.authorize()
            configurationStore.gmailConfiguration = configuration
            errorMessage = nil
            await loadNewsletters(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setScrollOffset(_ offset: Double, for newsletter: Newsletter) {
        guard let index = newsletters.firstIndex(where: { $0.id == newsletter.id }) else { return }
        newsletters[index].scrollOffset = offset
        persist()
    }

    func archive(_ newsletter: Newsletter) async {
        guard configurationStore.gmailConfiguration.isAuthorized else { return }
        do {
            try await gmailClient.archiveMessage(id: newsletter.id, configuration: configurationStore.gmailConfiguration)
            newsletters.removeAll { $0.id == newsletter.id }
            Task { await cache.removeContent(for: newsletter.id) }
            persist()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func persist() {
        do {
            let collection = NewsletterCollection(items: newsletters)
            let data = try JSONEncoder().encode(collection)
            let url = try persistenceURL()
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist newsletters: \(error)")
        }
    }

    private func shouldDisplay(message: GmailMessageResponse) async throws -> Bool {
        let headers = message.payload.headers
        let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? ""
        let from = headers.first(where: { $0.name.lowercased() == "from" })?.value ?? ""
        let preview = message.snippet
        let classification = try await openAIClient.classifyNewsletter(subject: subject + " from: " + from, bodyPreview: preview, apiKey: configurationStore.openAIAPIKey)
        return classification
    }

    private func makeNewsletter(from message: GmailMessageResponse) async throws -> Newsletter {
        guard let bodyData = decodeBody(from: message.payload) else {
            throw NewsletterError.missingContent
        }
        guard let htmlData = Data(base64Encoded: bodyData, options: .ignoreUnknownCharacters) else {
            throw NewsletterError.missingContent
        }
        let cacheURL = try await cache.store(html: htmlData, for: message.id)
        let headers = message.payload.headers
        let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? "(No Subject)"
        let from = headers.first(where: { $0.name.lowercased() == "from" })?.value ?? "Unknown sender"
        let dateString = headers.first(where: { $0.name.lowercased() == "date" })?.value ?? ""
        let parsedDate: Date
        if let headerDate = DateFormatter.rfc2822.date(from: dateString) {
            parsedDate = headerDate
        } else if let timestamp = TimeInterval(message.internalDate) {
            parsedDate = Date(timeIntervalSince1970: timestamp / 1000)
        } else {
            parsedDate = Date()
        }

        if let index = newsletters.firstIndex(where: { $0.id == message.id }) {
            var existing = newsletters[index]
            existing.subject = subject
            existing.snippet = message.snippet
            existing.receivedDate = parsedDate
            existing.sender = from
            existing.htmlContentPath = cacheURL
            return existing
        }

        return Newsletter(id: message.id,
                          subject: subject,
                          snippet: message.snippet,
                          receivedDate: parsedDate,
                          sender: from,
                          htmlContentPath: cacheURL,
                          scrollOffset: 0)
    }

    private func merge(existing: [Newsletter], with fetched: [Newsletter]) -> [Newsletter] {
        var dictionary = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in fetched {
            dictionary[item.id] = item
        }
        let merged = Array(dictionary.values)
        return merged.sorted(by: { $0.receivedDate > $1.receivedDate })
    }

    private func decodeBody(from payload: GmailMessageResponse.Payload) -> String? {
        if let body = payload.body?.data { return body }
        if let htmlPart = payload.parts?.first(where: { $0.mimeType == "text/html" }), let data = htmlPart.body?.data {
            return data
        }
        if let nested = payload.parts?.compactMap({ $0.parts }).flatMap({ $0 }), let html = nested.first(where: { $0.mimeType == "text/html" }) {
            return html.body?.data
        }
        return nil
    }

    private func loadPersistedNewsletters() {
        do {
            let url = try persistenceURL()
            let data = try Data(contentsOf: url)
            let collection = try JSONDecoder().decode(NewsletterCollection.self, from: data)
            newsletters = collection.items
        } catch {
            newsletters = []
        }
    }

    private func persistenceURL() throws -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("newsletters.json")
    }
}

private extension DateFormatter {
    static let rfc2822: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}
