import Foundation
import OSLog

public struct GrokClient: Sendable {
    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func chatCompletion(system: String, user: String) async throws -> String {
        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: 0.3
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        AppLog.api.debug("Grok request model=\(self.model, privacy: .public) bytes=\(request.httpBody?.count ?? 0, privacy: .public)")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GrokError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(500)) } ?? ""
            AppLog.api.error("Grok HTTP \(http.statusCode, privacy: .public) body=\(snippet, privacy: .public)")
            throw GrokError.httpStatus(http.statusCode, snippet)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            AppLog.api.error("Empty choices in Grok response")
            throw GrokError.emptyContent
        }
        return content
    }
}

public enum GrokError: Error, LocalizedError, Sendable {
    case invalidResponse
    case httpStatus(Int, String)
    case emptyContent

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Grok API."
        case .httpStatus(let code, let body):
            return "Grok API error (\(code)): \(body)"
        case .emptyContent:
            return "Grok returned an empty message."
        }
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]
}

private struct Choice: Decodable {
    let message: AssistantMessage
}

private struct AssistantMessage: Decodable {
    let content: String
}
