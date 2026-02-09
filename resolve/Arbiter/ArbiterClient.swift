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

        if stanceGroups.count == 1 {
            return try await summarizeSingleStance(
                stanceSummary: stanceGroups[0].stanceSummary,
                advocateResults: advocateResults,
                apiKey: apiKey
            )
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

    Formatting rule (important):
    - The UI will ONLY render bold text when it is wrapped in <bold>...</bold> tags.
    - Do NOT use Markdown (no **, no ***), headings, bullets, or lists.

    Task:

    You will be given multiple stance groups. For each stance group:

    Start with a single line exactly like this:
    "<provider1>, <provider2>, and <provider3> think:"
    Use "and" correctly. If there is only one provider, write:
    "<provider> thinks:"

    Then write one paragraph of 2–4 sentences explaining what that stance argues and why, based only on the provided explanations. Keep the language plain and human.

    For each group, make the main stance sentence bold by wrapping it in <bold>...</bold>, for example:
    <bold>This is the main stance sentence.</bold>

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

    static func summarizeChanges(
        previousGroups: [StanceGroup],
        previousResults: [AdvocateResult],
        newGroups: [StanceGroup],
        newResults: [AdvocateResult]
    ) async throws -> String {
        let previousMapping = buildProviderStanceMapping(stanceGroups: previousGroups)
        let newMapping = buildProviderStanceMapping(stanceGroups: newGroups)

        let previousStanceByProvider = stanceIDByProvider(from: previousMapping)
        let newStanceByProvider = stanceIDByProvider(from: newMapping)
        let changedProviders = AdvocateProvider.allCases
            .map { $0.displayName }
            .filter { previousStanceByProvider[$0] != nil && newStanceByProvider[$0] != nil && previousStanceByProvider[$0] != newStanceByProvider[$0] }

        if changedProviders.isEmpty {
            return "All advocates stood by their stances."
        }

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
You are an arbiter. Summarize CHANGES ONLY between two rounds.

Hard rules:
- If no provider changed stance_id, output exactly: All advocates stood by their stances.
- Otherwise, output one short paragraph per provider who changed stance.
- No headings. No bullet points. No markdown. No stance IDs (like S1/S2) in output.
- Provider names must exactly match the input provider names.

Output format for each changed provider (single sentence):
<Provider> changed stance from <old stance summary> to <new stance summary> because <brief reason>.

Use stance summaries from the mappings. The reason should be a brief plain-English clause based on the provided summaries/explanations.
"""

        let previousResultsJSON = prettyPrintedJSON(buildProviderResultItems(previousResults)) ?? "[]"
        let newResultsJSON = prettyPrintedJSON(buildProviderResultItems(newResults)) ?? "[]"
        let previousMappingJSON = prettyPrintedJSON(previousMapping) ?? "[]"
        let newMappingJSON = prettyPrintedJSON(newMapping) ?? "[]"
        let changedProvidersJSON = prettyPrintedJSON(changedProviders) ?? "[]"

        let userPrompt = """
You will receive previous and new data.

CHANGED_PROVIDERS (JSON array, these providers changed stance_id):
\(changedProvidersJSON)

PREVIOUS_STANCE_MAPPING (JSON array):
\(previousMappingJSON)

NEW_STANCE_MAPPING (JSON array):
\(newMappingJSON)

PREVIOUS_RESULTS (JSON array of provider, summary, explanation):
\(previousResultsJSON)

NEW_RESULTS (JSON array of provider, summary, explanation):
\(newResultsJSON)

Write one sentence paragraph per provider in CHANGED_PROVIDERS, in the same order as listed.
"""

        let body = RequestBody(
            model: "gpt-4.1-nano",
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.2,
            maxTokens: 500
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

    private static func summarizeSingleStance(
        stanceSummary: String,
        advocateResults: [AdvocateResult],
        apiKey: String
    ) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ArbiterError(message: "Invalid API URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let system = """
You write a brief rationale paragraph for a single shared stance.

Hard rules:
- Do NOT mention any provider names.
- Do NOT use Markdown.
- Output only 1–3 sentences (one paragraph).
"""

        let summaries = advocateResults
            .map { $0.summary.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let explanations = advocateResults
            .map { $0.explanation.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let user = """
STANCE (one sentence):
\(stanceSummary)

ADVOCATE SUMMARIES:
\(summaries.map { "- \($0)" }.joined(separator: "\n"))

ADVOCATE EXPLANATIONS:
\(explanations.joined(separator: "\n\n---\n\n"))
"""

        let body = RequestBody(
            model: "gpt-4.1-nano",
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: 0.2,
            maxTokens: 220
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
        let rationale = (decoded.choices.first?.message.content ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let header = "All advocates agreed with this stance: <bold>\(stanceSummary)</bold>"

        if rationale.isEmpty {
            return header
        }

        return header + "\n" + rationale
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

    private static func stanceIDByProvider(from mappingItems: [[String: String]]) -> [String: String] {
        var map: [String: String] = [:]
        for item in mappingItems {
            if let provider = item["provider"], let stanceID = item["stance_id"] {
                map[provider] = stanceID
            }
        }
        return map
    }

    private static func buildProviderResultItems(_ results: [AdvocateResult]) -> [[String: String]] {
        let byProvider = Dictionary(uniqueKeysWithValues: results.map { ($0.provider, $0) })
        return AdvocateProvider.allCases.compactMap { provider in
            guard let result = byProvider[provider] else { return nil }
            return [
                "provider": result.providerName,
                "summary": result.summary,
                "explanation": result.explanation
            ]
        }
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
