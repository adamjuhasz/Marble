//
//  NewsletterCache.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation

actor NewsletterCache {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            directoryURL = cachesDirectory.appendingPathComponent("NewsletterCache", isDirectory: true)
        } else {
            directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("NewsletterCache", isDirectory: true)
        }

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    func store(html: Data, for id: String) throws -> URL {
        let url = directoryURL.appendingPathComponent("\(id).html")
        do {
            try html.write(to: url, options: .atomic)
            return url
        } catch {
            throw NewsletterError.cachingFailed
        }
    }

    func loadContent(for id: String) -> URL? {
        let url = directoryURL.appendingPathComponent("\(id).html")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func removeContent(for id: String) {
        let url = directoryURL.appendingPathComponent("\(id).html")
        try? fileManager.removeItem(at: url)
    }
}
