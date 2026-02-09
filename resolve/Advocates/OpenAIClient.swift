import Foundation

enum OpenAIClient {
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
        let apiKey = APIKeys.ADVOCATE_ONE
        guard !apiKey.isEmpty else {
            return AdvocateClient.missingKeyResult(provider: .openAI)
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return AdvocateClient.errorResult(provider: .openAI, message: "Invalid OpenAI URL.")
        }

        let body = RequestBody(
            model: "gpt-4.1-mini",
            messages: [
                Message(role: "system", content: AdvocateSystemPrompts.ADVOCATE_OPENAI_SYSTEM),
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
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return AdvocateClient.errorResult(provider: .openAI, message: "OpenAI request failed.")
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            let content = decoded.choices.first?.message.content ?? ""
            let parsed = AdvocateClient.parseResponse(content)
            return AdvocateResult(provider: .openAI, explanation: parsed.explanation, summary: parsed.summary)
        } catch {
            return AdvocateClient.errorResult(provider: .openAI, message: "OpenAI error: \(error.localizedDescription)")
        }
    }
}
