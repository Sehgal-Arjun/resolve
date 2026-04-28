import Foundation

enum LabelerClient {
    private static let service = ResolveAIService()
    private static let LABELER_SYSTEM_PROMPT = """
You are a parser. Do not answer the question.
Extract multiple-choice options from the pasted text and assign canonical labels A, B, C, …

Return ONLY valid JSON in this exact format:
{
  "ok": true,
  "question_stem": "the question text without options",
  "options": [
    {"label": "A", "text": "first option text"},
    {"label": "B", "text": "second option text"}
  ]
}

Or if extraction fails:
{
  "ok": false,
  "reason": "explanation of why extraction failed"
}

Rules:
- Extract options from these formats:
  • Labeled lists: A) option  B) option  or  1. option  2. option
  • Bulleted lists: - option  or  • option
  • Comma-separated: "apples, oranges, bananas, grapes"
  • Inline after question mark: "question? option1, option2, option3"
- Remove original labels (letters/numbers) but keep the option text
- Assign new labels sequentially starting from A
- question_stem should be only the question, without the options
- If fewer than 2 options found, return ok=false
- If more than 26 options found, return ok=false
- Never hallucinate options
- Never include explanation text outside JSON
"""
    
    static func labelMCQ(rawQuestion: String) async -> LabeledMCQ {
        do {
            let prompt = buildPrompt(system: LABELER_SYSTEM_PROMPT, user: rawQuestion)
            let response = try await service.labeller(prompt: prompt)
            let content = response.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let json = extractJSON(from: content) else {
                return LabeledMCQ(
                    ok: false,
                    reason: "Labeler returned non-JSON output.",
                    question_stem: nil,
                    options: nil
                )
            }

            do {
                let labeled = try JSONDecoder().decode(LabeledMCQ.self, from: Data(json.utf8))
                return labeled
            } catch {
                return LabeledMCQ(
                    ok: false,
                    reason: "JSON decode failed: \(error.localizedDescription). Content: \(json.prefix(200))",
                    question_stem: nil,
                    options: nil
                )
            }
        } catch {
            let errorDesc = "\(error)"
            return LabeledMCQ(
                ok: false,
                reason: "Labeler request failed: \(errorDesc.prefix(200))",
                question_stem: nil,
                options: nil
            )
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
