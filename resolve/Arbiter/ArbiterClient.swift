import Foundation

enum ArbiterClient {
    struct ArbiterError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func summarizeInitial(stanceGroups: [StanceGroup], advocateResults: [AdvocateResult]) async throws -> String {
        let apiKey = APIKeys.ARBITER
        guard !apiKey.isEmpty else {
            throw ArbiterError(message: "Missing API key. Add your OpenAI key in resolve/Config/APIKeys.swift (APIKeys.ARBITER).")
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ArbiterError(message: "Invalid API URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let system = """
You are an arbiter. Your job is to summarize the different stances held by the advocates and the reasoning behind each stance.
Do not choose a winner. Do not try to converge the stances. Do not debate.
Write in natural, human-sounding paragraphs. Avoid labels like “Summary:” and “Key reasons:”.
Keep it concise and readable.

Task:

If there is only one stance group, output exactly the following and nothing else:

"All advocates agree:" + new line +
<one concise sentence stating the shared conclusion>. 1-3 sentence BRIEF explanation of the advocates' reasoning.

Rules for the single-stance case:
- Do not list providers.
- Do not explain, justify, or restate.
- Output exactly one bolded sentence after the header.

If there are multiple stance groups, then for each group:

Start with a single line exactly like this:
“<provider1>, <provider2>, and <provider3> think:”
Use “and” correctly. If there is only one provider, write:
“<provider> thinks:”

Then write one paragraph of 2-4 sentences explaining what that stance argues and why, based only on the provided explanations. Keep the language plain and human.

For multiple-stance cases only, put EXACTLY TWO (2) asterisks on each side of the main sentence stating the stance to make it bold, for example:
"**This is the main stance sentence.**"

Do not use bullet points, headings, labels, stance IDs, provider repetition, or secondary summaries. Do not invent or extend claims.

Separate stance sections with a blank line. Order sections by increasing number of advocates.

The output must contain only the stance sections and nothing else.
"""

        let mapping = buildProviderStanceMapping(stanceGroups: stanceGroups)
        let mappingJSON = prettyPrintedJSON(mapping) ?? "[]"

        let explanations = advocateResults
            .map { "\($0.providerName):\n\($0.explanation)" }
            .joined(separator: "\n\n")

        let userPrompt = """
You will receive:
1) A stance mapping for each provider (which stance each provider belongs to).
2) The full explanations written by each provider.
Do what you have been instructed to in the task.

STANCE MAPPING (JSON array):
\(mappingJSON)

FULL EXPLANATIONS:
\(explanations)
"""

        let body = RequestBody(
            model: "gpt-4.1-nano",
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.2,
            maxTokens: 850
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArbiterError(message: "Request failed. No HTTP response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let decoded = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw ArbiterError(message: "Arbiter HTTP \(httpResponse.statusCode): \(decoded.error.message)")
            }

            let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw ArbiterError(message: "Arbiter HTTP \(httpResponse.statusCode): \(bodyText)")
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let text = (decoded.choices.first?.message.content ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw ArbiterError(message: "Arbiter returned an empty response.")
        }

        return text
    }

    private static func buildProviderStanceMapping(stanceGroups: [StanceGroup]) -> [[String: String]] {
        let sortedGroups = stanceGroups.sorted { $0.stanceID < $1.stanceID }
        var items: [[String: String]] = []

        for group in sortedGroups {
            for provider in group.members {
                items.append([
                    "provider": provider.displayName,
                    "stance_id": group.stanceID,
                    "stance_summary": group.stanceSummary
                ])
            }
        }

        return items
    }

    private static func prettyPrintedJSON(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

private extension ArbiterClient {
    struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
    }

    struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    struct OpenAIErrorResponse: Decodable {
        struct ErrorDetail: Decodable {
            let message: String
        }
        let error: ErrorDetail
    }
}
