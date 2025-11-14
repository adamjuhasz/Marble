//
//  ConfigurationStore.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation
import Security

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published var openAIAPIKey: String {
        didSet { saveAPIKey(openAIAPIKey) }
    }

    @Published var gmailConfiguration: GmailConfiguration {
        didSet { persistGmailConfiguration(gmailConfiguration) }
    }

    private let keychainService = "com.ajuhasz.marble.configuration"
    private let openAIAccount = "openai_api_key"
    private let gmailDefaultsKey = "gmailConfiguration"

    init(userDefaults: UserDefaults = .standard) {
        let storedKey = Self.loadAPIKey(service: keychainService, account: openAIAccount) ?? ""
        openAIAPIKey = storedKey

        if let data = userDefaults.data(forKey: gmailDefaultsKey),
           let configuration = try? JSONDecoder().decode(GmailConfiguration.self, from: data) {
            gmailConfiguration = configuration
        } else {
            gmailConfiguration = .init()
        }
    }

    private func saveAPIKey(_ key: String) {
        do {
            try Self.storeAPIKey(key, service: keychainService, account: openAIAccount)
        } catch {
            print("Failed to save API key: \(error)")
        }
    }

    private func persistGmailConfiguration(_ configuration: GmailConfiguration) {
        do {
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: gmailDefaultsKey)
        } catch {
            print("Failed to persist Gmail configuration: \(error)")
        }
    }
}

// MARK: - Keychain helpers

private extension ConfigurationStore {
    static func storeAPIKey(_ key: String, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        guard !key.isEmpty, let data = key.data(using: .utf8) else {
            return
        }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    static func loadAPIKey(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct KeychainError: Error {
    let status: OSStatus
}
