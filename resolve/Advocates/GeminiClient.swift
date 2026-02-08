import Foundation

enum GeminiClient {
    private struct RequestBody: Encodable {
        struct Content: Encodable {
            struct Part: Encodable {
                let text: String
            }

            let role: String
            let parts: [Part]
        }

        struct SystemInstruction: Encodable {
            struct Part: Encodable {
                let text: String
            }

            let parts: [Part]
        }

        struct GenerationConfig: Encodable {
            let temperature: Double
            let maxOutputTokens: Int
        }

        let systemInstruction: SystemInstruction
        let contents: [Content]
        let generationConfig: GenerationConfig
        
        enum CodingKeys: String, CodingKey {
            case systemInstruction = "system_instruction"
            case contents
            case generationConfig
        }
    }

    private struct ResponseBody: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }

                let parts: [Part]
            }

            let content: Content
        }

        let candidates: [Candidate]
    }

    static func fetch(userMessage: String) async -> AdvocateResult {
        let apiKey = APIKeys.ADVOCATE_THREE
        guard !apiKey.isEmpty else {
            return AdvocateClient.missingKeyResult(provider: .gemini)
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            return AdvocateClient.errorResult(provider: .gemini, message: "Invalid Gemini URL.")
        }

        let body = RequestBody(
            systemInstruction: .init(parts: [.init(text: AdvocateSystemPrompts.ADVOCATE_GEMINI_SYSTEM)]),
            contents: [
                .init(role: "user", parts: [.init(text: userMessage)])
            ],
            generationConfig: .init(temperature: 0.2, maxOutputTokens: 240)
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return AdvocateClient.errorResult(provider: .gemini, message: "Invalid response type.")
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                return AdvocateClient.errorResult(provider: .gemini, message: "HTTP \(httpResponse.statusCode): \(errorBody.prefix(200))")
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            let content = decoded.candidates.first?.content.parts.compactMap { $0.text }.joined() ?? ""
            let parsed = AdvocateClient.parseResponse(content)
            return AdvocateResult(provider: .gemini, explanation: parsed.explanation, summary: parsed.summary)
        } catch {
            return AdvocateClient.errorResult(provider: .gemini, message: "Gemini error: \(error.localizedDescription)")
        }
    }
}
