import Foundation

enum DeepSeekClient {
    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let maxTokens: Int
        let temperature: Double

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case maxTokens = "max_tokens"
            case temperature
        }
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
    }

    static func fetch(userMessage: String) async -> AdvocateResult {
        let apiKey = APIKeys.ADVOCATE_FOUR
        guard !apiKey.isEmpty else {
            return AdvocateClient.missingKeyResult(provider: .deepSeek)
        }

        guard let url = URL(string: "https://api.deepseek.com/chat/completions") else {
            return AdvocateClient.errorResult(provider: .deepSeek, message: "Invalid DeepSeek URL.")
        }

        let body = RequestBody(
            model: "deepseek-chat",
            messages: [
                Message(role: "system", content: AdvocateSystemPrompts.ADVOCATE_DEEPSEEK_SYSTEM),
                Message(role: "user", content: userMessage)
            ],
            maxTokens: 240,
            temperature: 0.2
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return AdvocateClient.errorResult(provider: .deepSeek, message: "Invalid response type.")
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                return AdvocateClient.errorResult(provider: .deepSeek, message: "HTTP \(httpResponse.statusCode): \(errorBody.prefix(200))")
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            let content = decoded.choices.first?.message.content ?? ""
            let parsed = AdvocateClient.parseResponse(content)
            return AdvocateResult(provider: .deepSeek, explanation: parsed.explanation, summary: parsed.summary)
        } catch {
            return AdvocateClient.errorResult(provider: .deepSeek, message: "DeepSeek error: \(error.localizedDescription)")
        }
    }
}
