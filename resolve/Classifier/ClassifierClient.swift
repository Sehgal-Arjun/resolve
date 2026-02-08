import Foundation

enum ClassifierClient {
    private static let CLASSIFIER_SYSTEM_PROMPT = """
You are a classifier. Do not answer the question.
Group the following short answers by semantic stance.

Rules:
- Group answers that mean the same thing, even if worded differently.
- Each answer must belong to exactly one group.
- Do not judge which stance is correct.
- Do not invent new stances.
- Do not omit any input.
- Return ONLY valid JSON matching the schema below.
- Keep stance summaries short (max ~15 words).

Schema:
{
  "groups": [
    {
      "stance_id": "S1",
      "members": ["provider1", "provider2"],
      "stance_summary": "short description of the shared stance"
    }
  ]
}
"""

    private struct InputItem: Encodable {
        let provider: String
        let summary: String
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int
        let responseFormat: ResponseFormat

        struct ResponseFormat: Encodable {
            let type: String
        }

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
            case responseFormat = "response_format"
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

    struct ClassifierOutput: Decodable {
        struct Group: Decodable {
            let stance_id: String
            let members: [String]
            let stance_summary: String
        }
        let groups: [Group]
    }

    static func classifyNarrative(summaries: [AdvocateResult]) async -> ClassifierOutput? {
        let apiKey = APIKeys.LABELLER
        guard !apiKey.isEmpty else {
            return nil
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }

        let items = summaries.map {
            InputItem(provider: $0.provider.rawValue, summary: $0.summary)
        }

        let inputJSON: String
        do {
            let data = try JSONEncoder().encode(items)
            inputJSON = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return nil
        }

        let userContent = """
Group these summaries by stance. Input (JSON array):
\(inputJSON)
"""

        let body = RequestBody(
            model: "gpt-4.1-nano",
            messages: [
                Message(role: "system", content: CLASSIFIER_SYSTEM_PROMPT),
                Message(role: "user", content: userContent)
            ],
            temperature: 0.1,
            maxTokens: 500,
            responseFormat: RequestBody.ResponseFormat(type: "json_object")
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                return nil
            }

            return try JSONDecoder().decode(ClassifierOutput.self, from: Data(content.utf8))
        } catch {
            return nil
        }
    }
}
