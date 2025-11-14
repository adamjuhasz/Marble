//
//  SettingsView.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var configurationStore: ConfigurationStore
    @EnvironmentObject private var store: NewsletterStore
    @State private var apiKey: String = ""
    @State private var showKey = false

    var body: some View {
        Form {
            Section("OpenAI") {
                Group {
                    if showKey {
                        TextField("API Key", text: $apiKey)
                    } else {
                        SecureField("API Key", text: $apiKey)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                Toggle("Show API Key", isOn: $showKey)
                Button("Copy") {
                    UIPasteboard.general.string = apiKey
                }
                .disabled(apiKey.isEmpty)
                Button("Save") {
                    configurationStore.openAIAPIKey = apiKey
                    Task { await store.loadNewsletters(force: true) }
                }
                .disabled(apiKey.isEmpty)
            }

            Section("Gmail") {
                if configurationStore.gmailConfiguration.isAuthorized {
                    Label(configurationStore.gmailConfiguration.userEmail, systemImage: "envelope")
                    Button("Disconnect") {
                        configurationStore.gmailConfiguration = .init()
                    }
                    .foregroundStyle(.red)
                } else {
                    Button("Connect Gmail") {
                        Task { await store.authorizeGmail() }
                    }
                    Text("Provide your OAuth Client ID and redirect URI in Info.plist before connecting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                Text("Marble helps you focus on the newsletters you care about by filtering your Gmail inbox using on-device caching and your own OpenAI API key.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            apiKey = configurationStore.openAIAPIKey
        }
    }
}
