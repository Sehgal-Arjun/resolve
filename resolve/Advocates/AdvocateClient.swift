import Foundation

enum AdvocateClient {
    static let placeholderResults: [AdvocateResult] = [
        AdvocateResult(provider: .openAI, explanation: "Awaiting response.", summary: "Awaiting response."),
        AdvocateResult(provider: .anthropic, explanation: "Awaiting response.", summary: "Awaiting response."),
        AdvocateResult(provider: .gemini, explanation: "Awaiting response.", summary: "Awaiting response."),
        AdvocateResult(provider: .deepSeek, explanation: "Awaiting response.", summary: "Awaiting response."),
        AdvocateResult(provider: .mistral, explanation: "Awaiting response.", summary: "Awaiting response.")
    ]

    static func fetchAllAdvocates(
        problemType: ProblemType,
        question: String,
        options: [String]?
    ) async -> [AdvocateResult] {
        await withTaskGroup(of: AdvocateResult.self) { group in
            let userMessage = buildAdvocateUserMessage(
                problemType: problemType,
                question: question,
                options: options
            )

            group.addTask { await OpenAIClient.fetch(userMessage: userMessage) }
            group.addTask { await AnthropicClient.fetch(userMessage: userMessage) }
            group.addTask { await GeminiClient.fetch(userMessage: userMessage) }
            group.addTask { await DeepSeekClient.fetch(userMessage: userMessage) }
            group.addTask { await MistralClient.fetch(userMessage: userMessage) }

            var results: [AdvocateResult] = []
            for await result in group {
                results.append(result)
            }

            let order = AdvocateProvider.allCases
            return results.sorted {
                guard let leftIndex = order.firstIndex(of: $0.provider),
                      let rightIndex = order.firstIndex(of: $1.provider) else {
                    return $0.provider.rawValue < $1.provider.rawValue
                }
                return leftIndex < rightIndex
            }
        }
    }

    static func parseResponse(_ response: String) -> (explanation: String, summary: String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        let explanationLine = lines.first { $0.hasPrefix("EXPLANATION:") }
        let summaryLine = lines.first { $0.hasPrefix("SUMMARY:") }

        if let explanationLine, let summaryLine {
            let explanation = explanationLine.replacingOccurrences(of: "EXPLANATION:", with: "")
                .trimmingCharacters(in: .whitespaces)
            let summary = summaryLine.replacingOccurrences(of: "SUMMARY:", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !explanation.isEmpty && !summary.isEmpty {
                return (explanation, summary)
            }
        }

        let fallbackSummary = truncateWords(firstSentence(from: trimmed), maxWords: 22)
        return (trimmed, fallbackSummary.isEmpty ? "No summary available." : fallbackSummary)
    }

    static func missingKeyResult(provider: AdvocateProvider) -> AdvocateResult {
        AdvocateResult(
            provider: provider,
            explanation: "Missing API key for \(provider.displayName).",
            summary: "Missing API key."
        )
    }

    static func errorResult(provider: AdvocateProvider, message: String) -> AdvocateResult {
        AdvocateResult(provider: provider, explanation: message, summary: "No response.")
    }

    static func buildAdvocateUserMessage(
        problemType: ProblemType,
        question: String,
        options: [String]?
    ) -> String {
        let normalizedType: String
        let summaryFormat: String
        let optionsLine: String?

        switch problemType {
        case .multipleChoiceSingle:
            normalizedType = "SINGLE_SELECT"
            summaryFormat = "Output ONLY the single best option letter (A/B/C/D). No other text."
            let resolvedOptions = resolveOptions(options, question: question)
            let formattedOptions = formatOptions(resolvedOptions)
            optionsLine = "OPTIONS: \(formattedOptions)"
        case .multipleChoiceMulti:
            normalizedType = "MULTI_SELECT"
            summaryFormat = "Output ONLY a comma+space separated list of option letters in sorted order (e.g. ‘A, C, D’). No other text."
            let resolvedOptions = resolveOptions(options, question: question)
            let formattedOptions = formatOptions(resolvedOptions)
            optionsLine = "OPTIONS: \(formattedOptions)"
        case .generalQuestion, .comparison:
            normalizedType = "NARRATIVE"
            summaryFormat = "Output exactly one sentence (max 22 words) that directly answers the question."
            optionsLine = nil
        }

        var lines: [String] = [
            "PROBLEM_TYPE: \(normalizedType)",
            "SUMMARY_FORMAT: \(summaryFormat)",
            "QUESTION: \(question)"
        ]

        if let optionsLine {
            lines.append(optionsLine)
        }

        return lines.joined(separator: "\n")
    }

    private static func firstSentence(from text: String) -> String {
        if let range = text.range(of: #"[.!?]"#, options: .regularExpression) {
            return String(text[..<range.upperBound])
        }
        return text
    }

    private static func truncateWords(_ text: String, maxWords: Int) -> String {
        let words = text.split(separator: " ")
        if words.count <= maxWords {
            return text
        }
        return words.prefix(maxWords).joined(separator: " ") + "…"
    }

    private static func formatOptions(_ options: [String]) -> String {
        let values = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return values.enumerated().map { index, value in
            let letter = String(UnicodeScalar(65 + index)!)
            return "\(letter)) \(value)"
        }.joined(separator: " ")
    }

    private static func resolveOptions(_ options: [String]?, question: String) -> [String] {
        let normalized = options?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if let normalized, !normalized.isEmpty {
            return normalized
        }

        let extracted = extractOptions(from: question)
        if !extracted.isEmpty {
            return extracted
        }

        return ["Option 1", "Option 2", "Option 3", "Option 4"]
    }

    private static func extractOptions(from question: String) -> [String] {
        let pattern = #"(?m)(^|\s)([A-D])\s*[\)\.\:\-\]]\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let ns = question as NSString
        let matches = regex.matches(in: question, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [] }

        var results: [String] = []

        for index in 0..<matches.count {
            let match = matches[index]
            let contentStart = match.range.location + match.range.length
            let contentEnd: Int
            if index + 1 < matches.count {
                contentEnd = matches[index + 1].range.location
            } else {
                contentEnd = ns.length
            }

            let length = max(0, contentEnd - contentStart)
            let range = NSRange(location: contentStart, length: length)
            let raw = ns.substring(with: range)
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                results.append(cleaned)
            }
        }

        return results
    }
}
