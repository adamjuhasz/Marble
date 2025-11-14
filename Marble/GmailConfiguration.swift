//
//  GmailConfiguration.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation

struct GmailConfiguration: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expirationDate: Date
    var userEmail: String

    init(accessToken: String = "", refreshToken: String = "", expirationDate: Date = .distantPast, userEmail: String = "") {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expirationDate = expirationDate
        self.userEmail = userEmail
    }

    var isAuthorized: Bool {
        !accessToken.isEmpty && !refreshToken.isEmpty && !userEmail.isEmpty
    }

    var needsRefresh: Bool {
        Date() >= expirationDate.addingTimeInterval(-300)
    }
}
