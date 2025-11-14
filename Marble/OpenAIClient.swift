//
//  OpenAIClient.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import Foundation

struct OpenAIClient {
    enum Model: String {
        case gpt4oMini = "gpt-4o-mini"
    }

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func classifyNewsletter(subject: String, bodyPreview: String, apiKey: String) async throws -> Bool {
        guard !apiKey.isEmpty else { throw NewsletterError.requestFailed("Missing OpenAI API key") }

        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = "You are categorizing email messages for a newsletter reading app. Respond with only 'newsletter' or 'other'.\nSubject: \(subject)\nPreview: \(bodyPreview)"
        let payload = OpenAIRequest(model: Model.gpt4oMini.rawValue, input: prompt, maxOutputTokens: 5)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsletterError.requestFailed("OpenAI classification failed")
        }

        let result = try decoder.decode(OpenAIResponse.self, from: data)
        let text = result.outputText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return text.contains("newsletter")
    }
}

private struct OpenAIRequest: Encodable {
    let model: String
    let input: String
    let maxOutputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case model
        case input
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct OpenAIResponse: Decodable {
    struct Content: Decodable {
        struct TextSegment: Decodable {
            let text: String
        }

        let text: [TextSegment]?
    }

    let output: [Content]

    var outputText: String {
        output.compactMap { $0.text?.first?.text }.joined(separator: " ")
    }
}
