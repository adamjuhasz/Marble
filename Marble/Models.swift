//
//  Models.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation

struct Newsletter: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var subject: String
    var snippet: String
    var receivedDate: Date
    var sender: String
    var htmlContentPath: URL
    var scrollOffset: Double

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: receivedDate)
    }
}

struct NewsletterCollection: Codable {
    var items: [Newsletter]
}

enum NewsletterError: LocalizedError {
    case authorizationRequired
    case missingContent
    case requestFailed(String)
    case decodingFailed
    case cachingFailed

    var errorDescription: String? {
        switch self {
        case .authorizationRequired:
            return "You need to connect Gmail before you can load newsletters."
        case .missingContent:
            return "We were unable to load the contents of this newsletter."
        case .requestFailed(let message):
            return "The request failed: \(message)."
        case .decodingFailed:
            return "We could not decode the response from the server."
        case .cachingFailed:
            return "We were unable to cache this message for offline use."
        }
    }
}
