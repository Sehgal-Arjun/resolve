import Foundation

enum ProblemType: String, CaseIterable, Identifiable {
    case multipleChoiceSingle = "Multiple Choice – Single Select"
    case multipleChoiceMulti = "Multiple Choice – Multi Select"
    case generalQuestion = "General Question"
    case comparison = "Comparison"

    var id: String { rawValue }
}

enum AdvocateProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Gemini"
    case deepSeek = "DeepSeek"
    case mistral = "Mistral"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "ChatGPT"
        case .anthropic:
            return "Claude"
        case .gemini:
            return "Gemini"
        case .deepSeek:
            return "DeepSeek"
        case .mistral:
            return "Mistral"
        }
    }
}

struct AdvocateResult: Identifiable {
    let provider: AdvocateProvider
    let explanation: String
    let summary: String

    var providerName: String {
        provider.displayName
    }

    var id: String {
        provider.id
    }
}
