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
        // For MCQ types, run labeler first to extract canonical options
        if problemType == .multipleChoiceSingle || problemType == .multipleChoiceMulti {
            let labeled = await LabelerClient.labelMCQ(rawQuestion: question)
            
            if !labeled.ok {
                let reason = labeled.reason ?? "Could not reliably detect multiple-choice options."
                let errorMessage = "\(reason) Please paste options as a list or switch to General Question."
                
                return placeholderResults.map { result in
                    AdvocateResult(
                        provider: result.provider,
                        explanation: errorMessage,
                        summary: "Options not detected."
                    )
                }
            }
            
            guard let questionStem = labeled.question_stem,
                  let labeledOptions = labeled.options,
                  labeledOptions.count >= 2,
                  labeledOptions.count <= 26 else {
                return placeholderResults.map { result in
                    AdvocateResult(
                        provider: result.provider,
                        explanation: "Labeler returned invalid structure. Please paste options clearly or switch to General Question.",
                        summary: "Invalid options."
                    )
                }
            }
            
            // Build advocate message using labeled output
            let userMessage = buildAdvocateUserMessageFromLabeled(
                problemType: problemType,
                questionStem: questionStem,
                options: labeledOptions
            )
            
            return await fetchAdvocatesWithMessage(userMessage)
        }
        
        // For non-MCQ types, skip labeler and use existing flow
        let userMessage = buildAdvocateUserMessage(
            problemType: problemType,
            question: question,
            options: options
        )
        
        return await fetchAdvocatesWithMessage(userMessage)
    }

    static func reconsiderAllAdvocates(
        problemType: ProblemType,
        question: String,
        labeledOptions: [LabeledOption]?,
        previousResults: [AdvocateResult],
        stanceGroups: [StanceGroup]
    ) async -> [AdvocateResult] {
        if problemType == .multipleChoiceSingle || problemType == .multipleChoiceMulti {
            guard let labeledOptions, labeledOptions.count >= 2, labeledOptions.count <= 26 else {
                let message = "Missing labeled MCQ options for Resolve-round reconsideration. Re-run labeler and pass labeledOptions."
                return previousResults.map { result in
                    AdvocateResult(provider: result.provider, explanation: message, summary: result.summary)
                }
            }
        }

        let priorByProvider: [AdvocateProvider: AdvocateResult] = Dictionary(
            uniqueKeysWithValues: previousResults.map { ($0.provider, $0) }
        )

        let groupByProvider: [AdvocateProvider: StanceGroup] = stanceGroups.reduce(into: [:]) { partial, group in
            for member in group.members {
                partial[member] = group
            }
        }

        let order = AdvocateProvider.allCases
        let otherReasoningByProvider: [AdvocateProvider: String] = Dictionary(uniqueKeysWithValues: order.map { provider in
            let ownGroupMembers = Set(groupByProvider[provider]?.members ?? [])
            let otherProviders = order.filter { $0 != provider && !ownGroupMembers.contains($0) }
            let lines: [String] = otherProviders.compactMap { other in
                guard let prior = priorByProvider[other] else { return nil }
                return "\(prior.providerName):\n\(prior.explanation)"
            }
            return (provider, lines.joined(separator: "\n\n"))
        })

        return await withTaskGroup(of: AdvocateResult.self) { group in
            for provider in order {
                group.addTask {
                    let prior = priorByProvider[provider]
                    let userMessage = buildReconsiderUserMessage(
                        provider: provider,
                        problemType: problemType,
                        question: question,
                        labeledOptions: labeledOptions,
                        prior: prior,
                        otherReasoning: otherReasoningByProvider[provider] ?? ""
                    )

                    switch provider {
                    case .openAI:
                        return await OpenAIClient.fetch(userMessage: userMessage)
                    case .anthropic:
                        return await AnthropicClient.fetch(userMessage: userMessage)
                    case .gemini:
                        return await GeminiClient.fetch(userMessage: userMessage)
                    case .deepSeek:
                        return await DeepSeekClient.fetch(userMessage: userMessage)
                    case .mistral:
                        return await MistralClient.fetch(userMessage: userMessage)
                    }
                }
            }

            var results: [AdvocateResult] = []
            for await result in group {
                results.append(result)
            }

            return results.sorted {
                guard let leftIndex = order.firstIndex(of: $0.provider),
                      let rightIndex = order.firstIndex(of: $1.provider) else {
                    return $0.provider.rawValue < $1.provider.rawValue
                }
                return leftIndex < rightIndex
            }
        }
    }
    
    private static func fetchAdvocatesWithMessage(_ userMessage: String) async -> [AdvocateResult] {
        await withTaskGroup(of: AdvocateResult.self) { group in
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

    private static func buildReconsiderUserMessage(
        provider: AdvocateProvider,
        problemType: ProblemType,
        question: String,
        labeledOptions: [LabeledOption]?,
        prior: AdvocateResult?,
        otherReasoning: String
    ) -> String {
        let (normalizedType, summaryFormat, optionsLine) = resolveRoundHeader(
            problemType: problemType,
            labeledOptions: labeledOptions
        )

        let priorSummary = prior?.summary ?? ""
        let priorExplanation = prior?.explanation ?? ""

        var lines: [String] = [
            "PROBLEM_TYPE: \(normalizedType)",
            "SUMMARY_FORMAT: \(summaryFormat)",
            "QUESTION: \(question)"
        ]

        if let optionsLine {
            lines.append(optionsLine)
        }

        lines.append(contentsOf: [
            "",
            "YOUR_PREVIOUS_SUMMARY: \(priorSummary)",
            "YOUR_PREVIOUS_EXPLANATION: \(priorExplanation)",
            "",
            "OTHER_ADVOCATES_REASONING:",
            otherReasoning.isEmpty ? "(none)" : otherReasoning,
            "",
            "Instruction:",
            "Based on the other advocates’ reasoning, do you still stand by your previous stance?",
            "If you change your stance, say so clearly and explain why.",
            "If you keep your stance, explain why you are not persuaded.",
            "",
            "Output format (exact):",
            "EXPLANATION: <brief explanation, max 120 words>",
            "SUMMARY: <follow the SUMMARY_FORMAT requested above exactly>"
        ])

        return lines.joined(separator: "\n")
    }

    private static func resolveRoundHeader(
        problemType: ProblemType,
        labeledOptions: [LabeledOption]?
    ) -> (normalizedType: String, summaryFormat: String, optionsLine: String?) {
        switch problemType {
        case .multipleChoiceSingle:
            let labels = (labeledOptions ?? []).map { $0.label }
            let labelList = labels.isEmpty ? "A/B/C/D" : labels.joined(separator: "/")
            let formattedOptions = (labeledOptions ?? []).map { "\($0.label)) \($0.text)" }.joined(separator: " ")
            return (
                "SINGLE_SELECT",
                "Output ONLY the single best option letter (\(labelList)). No other text.",
                formattedOptions.isEmpty ? nil : "OPTIONS: \(formattedOptions)"
            )
        case .multipleChoiceMulti:
            let labels = (labeledOptions ?? []).map { $0.label }
            let sample = labels.prefix(3).joined(separator: ", ")
            let formattedOptions = (labeledOptions ?? []).map { "\($0.label)) \($0.text)" }.joined(separator: " ")
            return (
                "MULTI_SELECT",
                "Output ONLY a comma+space separated list of option letters in sorted order (e.g. '\(sample.isEmpty ? "A, B, D" : sample)'). No other text.",
                formattedOptions.isEmpty ? nil : "OPTIONS: \(formattedOptions)"
            )
        case .generalQuestion, .comparison:
            return (
                "NARRATIVE",
                "Output exactly one sentence (max 22 words) that directly answers the question.",
                nil
            )
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
        // Only called for generalQuestion and comparison - MCQ types use buildAdvocateUserMessageFromLabeled
        return [
            "PROBLEM_TYPE: NARRATIVE",
            "SUMMARY_FORMAT: Output exactly one sentence (max 22 words) that directly answers the question.",
            "QUESTION: \(question)"
        ].joined(separator: "\n")
    }
    
    private static func buildAdvocateUserMessageFromLabeled(
        problemType: ProblemType,
        questionStem: String,
        options: [LabeledOption]
    ) -> String {
        let normalizedType: String
        let summaryFormat: String
        
        switch problemType {
        case .multipleChoiceSingle:
            normalizedType = "SINGLE_SELECT"
            summaryFormat = "Output ONLY the single best option letter (\(options.map { $0.label }.joined(separator: "/"))). No other text."
        case .multipleChoiceMulti:
            normalizedType = "MULTI_SELECT"
            summaryFormat = "Output ONLY a comma+space separated list of option letters in sorted order (e.g. '\(options.prefix(3).map { $0.label }.joined(separator: ", "))'). No other text."
        case .generalQuestion, .comparison:
            normalizedType = "NARRATIVE"
            summaryFormat = "Output exactly one sentence (max 22 words) that directly answers the question."
        }
        
        let formattedOptions = options.map { "\($0.label)) \($0.text)" }.joined(separator: " ")
        
        var lines: [String] = [
            "PROBLEM_TYPE: \(normalizedType)",
            "SUMMARY_FORMAT: \(summaryFormat)",
            "QUESTION: \(questionStem)",
            "OPTIONS: \(formattedOptions)"
        ]
        
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
}
