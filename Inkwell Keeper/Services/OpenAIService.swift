//
//  OpenAIService.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 2/11/26.
//

import Foundation

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

class OpenAIService {
    static let shared = OpenAIService()

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let defaultModel = "gpt-4o-mini"

    private init() {}

    /// Streams a chat completion.
    /// - Parameters:
    ///   - model: Overrides the default model. Pass a stronger model for reasoning-heavy tasks.
    ///   - temperature: When provided, pins the sampling temperature. Lower values give more
    ///     deterministic, factual answers (use for the rules assistant).
    func streamChatCompletion(
        apiKey: String,
        messages: [OpenAIChatMessage],
        model: String? = nil,
        temperature: Double? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let resolvedModel = model ?? defaultModel
                    var body: [String: Any] = [
                        "model": resolvedModel,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]
                    // GPT-5-family and o-series reasoning models reject any
                    // non-default temperature with HTTP 400, so only attach it
                    // for the gpt-4 family, which accepts it.
                    if let temperature, resolvedModel.hasPrefix("gpt-4") {
                        body["temperature"] = temperature
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        // Error bodies are small JSON blobs explaining the
                        // rejection — capture one so failures are diagnosable
                        // from the console instead of a bare status code.
                        var detail = ""
                        for try await line in bytes.lines {
                            detail += line
                            if detail.count > 500 { break }
                        }
                        print("[OpenAI] HTTP \(httpResponse.statusCode): \(detail)")
                        continuation.finish(
                            throwing: OpenAIError.httpError(httpResponse.statusCode, detail: detail)
                        )
                        return
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))

                        if data == "[DONE]" { break }

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }

                        continuation.yield(content)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

enum OpenAIError: LocalizedError {
    case invalidResponse
    case httpError(Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        case let .httpError(code, detail):
            return "OpenAI API returned HTTP \(code)\(detail.isEmpty ? "" : ": \(detail)")."
        }
    }
}
