import Foundation

enum LabelerClient {
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
    
    static func labelMCQ(rawQuestion: String) async -> LabeledMCQ {
        let apiKey = APIKeys.LABELLER
        guard !apiKey.isEmpty else {
            return LabeledMCQ(
                ok: false,
                reason: "Labeler API key not configured.",
                question_stem: nil,
                options: nil
            )
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return LabeledMCQ(
                ok: false,
                reason: "Invalid labeler URL.",
                question_stem: nil,
                options: nil
            )
        }
        
        let body = RequestBody(
            model: "gpt-4o-mini",
            messages: [
                Message(role: "system", content: LABELER_SYSTEM_PROMPT),
                Message(role: "user", content: rawQuestion)
            ],
            temperature: 0.1,
            maxTokens: 600,
            responseFormat: RequestBody.ResponseFormat(type: "json_object")
        )
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return LabeledMCQ(
                    ok: false,
                    reason: "Invalid response type from labeler.",
                    question_stem: nil,
                    options: nil
                )
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                return LabeledMCQ(
                    ok: false,
                    reason: "Labeler HTTP \(httpResponse.statusCode): \(errorBody.prefix(100))",
                    question_stem: nil,
                    options: nil
                )
            }
            
            let responseBody = try JSONDecoder().decode(ResponseBody.self, from: data)
            guard let content = responseBody.choices.first?.message.content else {
                return LabeledMCQ(
                    ok: false,
                    reason: "Labeler returned empty content.",
                    question_stem: nil,
                    options: nil
                )
            }
            
            do {
                let labeled = try JSONDecoder().decode(LabeledMCQ.self, from: Data(content.utf8))
                return labeled
            } catch {
                return LabeledMCQ(
                    ok: false,
                    reason: "JSON decode failed: \(error.localizedDescription). Content: \(content.prefix(200))",
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
}
