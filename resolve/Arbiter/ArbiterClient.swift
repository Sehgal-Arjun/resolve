import Foundation

enum ArbiterClient {
    private static let service = ResolveAIService()
    struct ArbiterError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func summarizeInitial(stanceGroups: [StanceGroup], advocateResults: [AdvocateResult]) async throws -> String {
        if stanceGroups.count == 1 {
            return try await summarizeSingleStance(
                stanceSummary: stanceGroups[0].stanceSummary,
                advocateResults: advocateResults
            )
        }

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
        return try await callArbiter(system: system, user: userPrompt)
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
        return try await callArbiter(system: system, user: userPrompt)
    }

    private static func summarizeSingleStance(
        stanceSummary: String,
        advocateResults: [AdvocateResult]
    ) async throws -> String {
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
        let rationale = try await callArbiter(system: system, user: user)

        let header = "All advocates agreed with this stance: <bold>\(stanceSummary)</bold>"

        if rationale.isEmpty {
            return header
        }

        return header + "\n" + rationale
    }

    private static func callArbiter(system: String, user: String) async throws -> String {
        let prompt = "SYSTEM:\n\(system)\n\nUSER:\n\(user)"

        do {
            let response = try await service.arbiter(prompt: prompt)
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                throw ArbiterError(message: "Arbiter returned an empty response.")
            }
            return text
        } catch let error as ArbiterError {
            throw error
        } catch {
            throw ArbiterError(message: "Arbiter request failed: \(error)")
        }
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
