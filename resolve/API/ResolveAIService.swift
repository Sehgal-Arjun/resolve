import Foundation

final class ResolveAIService {
    private let client: BackendAIClient

    init(client: BackendAIClient = BackendAIClient()) {
        self.client = client
    }

    func advocateOne(prompt: String) async throws -> AIResponse {
        try await client.call(model: "gpt-4o-mini", prompt: prompt)
    }

    func advocateTwo(prompt: String) async throws -> AIResponse {
        try await client.call(model: "claude-sonnet-4", prompt: prompt)
    }

    func advocateThree(prompt: String) async throws -> AIResponse {
        try await client.call(model: "gemini-1.5-flash", prompt: prompt)
    }

    func advocateFour(prompt: String) async throws -> AIResponse {
        try await client.call(model: "deepseek", prompt: prompt)
    }

    func advocateFive(prompt: String) async throws -> AIResponse {
        try await client.call(model: "mistral", prompt: prompt)
    }

    func labeller(prompt: String) async throws -> AIResponse {
        try await client.call(model: "gpt-4.1-nano-labeller", prompt: prompt)
    }

    func classifier(prompt: String) async throws -> AIResponse {
        try await client.call(model: "gpt-4.1-nano-classifier", prompt: prompt)
    }

    func arbiter(prompt: String) async throws -> AIResponse {
        try await client.call(model: "gpt-4.1-nano-arbiter", prompt: prompt)
    }

    func runAdvocates(prompt: String) async -> [AIResponse] {
        let models: [(provider: String, model: String)] = [
            ("openai", "gpt-4o-mini"),
            ("anthropic", "claude-sonnet-4"),
            ("gemini", "gemini-1.5-flash"),
            ("deepseek", "deepseek"),
            ("mistral", "mistral")
        ]

        var results = Array<AIResponse?>(repeating: nil, count: models.count)

        await withTaskGroup(of: (Int, AIResponse).self) { group in
            for (index, entry) in models.enumerated() {
                group.addTask {
                    do {
                        let response = try await self.client.call(model: entry.model, prompt: prompt)
                        return (index, response)
                    } catch {
                        let placeholder = AIResponse(
                            provider: entry.provider,
                            model: entry.model,
                            text: "Error: \(error)",
                            latencyMs: 0,
                            requestId: "error"
                        )
                        return (index, placeholder)
                    }
                }
            }

            for await (index, response) in group {
                results[index] = response
            }
        }

        return results.compactMap { $0 }
    }
}
