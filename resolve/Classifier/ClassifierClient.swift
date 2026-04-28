import Foundation

enum ClassifierClient {
    private static let service = ResolveAIService()
    private static let CLASSIFIER_SYSTEM_PROMPT = """
You are a classifier. Do not answer the question.
You will be given a QUESTION and a JSON array of short answers (provider + summary).
Your job is to group the answers by semantic stance (the bottom-line conclusion), using the QUESTION as context.

Define the stance ONLY by the bottom-line outcome a reasonable reader would take away:
- For comparative questions (A vs B): which option is favored (A, B), or "tie/too close", or "depends/unclear".
- For yes/no questions: yes, no, or uncertain.

CRITICAL MERGING RULES (merge aggressively):
- Differences in strength or degree do NOT create separate stances.
  Treat these as the same stance: "A is better", "A is slightly better", "A edges it", "A marginally", "A clearly".
- Differences in tone, framing, caveats, examples, or reasons do NOT create separate stances.
- If two answers name the same winner/outcome, they MUST be in the same group.
- Only create separate groups when the bottom-line outcome differs (different winner, tie/too close, depends/unclear).

Do NOT judge which stance is correct.
Do NOT invent new stances.
Do NOT omit any input.
Each answer must belong to exactly one group.

Optimization objective:
- Produce the MINIMUM number of groups consistent with the rules above.
- When unsure, MERGE.

Output ONLY valid JSON matching this schema:
{
  "groups": [
    {
      "stance_id": "S1",
      "members": ["provider1", "provider2"],
      "stance_summary": "max ~12 words, states the bottom-line outcome"
    }
  ]
}

Stance summary guidance:
- For A vs B: "A is better", "B is better", "Too close/tie", or "Depends/unclear".
- Do not include reasons in the stance_summary.
"""

    private struct InputItem: Encodable {
        let provider: String
        let summary: String
    }

    struct ClassifierOutput: Decodable {
        struct Group: Decodable {
            let stance_id: String
            let members: [String]
            let stance_summary: String
        }
        let groups: [Group]
    }

    static func classifyNarrative(question: String, summaries: [AdvocateResult]) async -> ClassifierOutput? {
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

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let userContent = """
    QUESTION:
    \(trimmedQuestion)

    Group these summaries by stance. Input (JSON array):
    \(inputJSON)
    """

        do {
            let prompt = buildPrompt(system: CLASSIFIER_SYSTEM_PROMPT, user: userContent)
            let response = try await service.classifier(prompt: prompt)
            let content = response.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let json = extractJSON(from: content) else {
                return nil
            }

            return try JSONDecoder().decode(ClassifierOutput.self, from: Data(json.utf8))
        } catch {
            return nil
        }
    }

    private static func buildPrompt(system: String, user: String) -> String {
        "SYSTEM:\n\(system)\n\nUSER:\n\(user)"
    }

    private static func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        guard let end = text.lastIndex(of: "}") else { return nil }
        guard start < end else { return nil }
        return String(text[start...end])
    }
}
