//
//  AppModel.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation

@MainActor
final class AppModel: ObservableObject {
    let configurationStore: ConfigurationStore
    let newsletterStore: NewsletterStore

    init(configurationStore: ConfigurationStore = .init()) {
        self.configurationStore = configurationStore
        self.newsletterStore = NewsletterStore(configurationStore: configurationStore)
    }

    func persist() {
        newsletterStore.persist()
    }
}
