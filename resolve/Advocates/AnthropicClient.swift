import Foundation

enum AnthropicClient {
    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]
        let temperature: Double

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case system
            case messages
            case temperature
        }
    }

    private struct ResponseBody: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }

        let content: [ContentBlock]
    }

    static func fetch(userMessage: String) async -> AdvocateResult {
        let apiKey = APIKeys.ADVOCATE_TWO
        guard !apiKey.isEmpty else {
            return AdvocateClient.missingKeyResult(provider: .anthropic)
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return AdvocateClient.errorResult(provider: .anthropic, message: "Invalid Anthropic URL.")
        }

        let body = RequestBody(
            model: "claude-sonnet-4-20250514",
            maxTokens: 240,
            system: AdvocateSystemPrompts.ADVOCATE_ANTHROPIC_SYSTEM,
            messages: [Message(role: "user", content: userMessage)],
            temperature: 0.2
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "Anthropic-Version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return AdvocateClient.errorResult(provider: .anthropic, message: "Anthropic request failed.")
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            let content = decoded.content.compactMap { $0.text }.joined()
            let parsed = AdvocateClient.parseResponse(content)
            return AdvocateResult(provider: .anthropic, explanation: parsed.explanation, summary: parsed.summary)
        } catch {
            return AdvocateClient.errorResult(provider: .anthropic, message: "Anthropic error: \(error.localizedDescription)")
        }
    }
}
