import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String?
    let resolveCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title
        case resolveCount = "resolve_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MessageRow: Codable, Identifiable, Hashable {
    let id: UUID
    let conversationId: UUID
    let role: String
    let content: String
    let createdAt: Date
    let promptType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role, content
        case createdAt = "created_at"
        case promptType = "prompt_type"
    }
}

struct ConversationDetail: Codable, Hashable {
    let conversation: Conversation
    let messages: [MessageRow]
}

struct PostMessageResponse: Codable, Hashable {
    let message: MessageRow
    let run: RunResult
}

struct RunResult: Codable, Hashable {

    struct ClassifierOutput: Codable, Hashable {
        let outputJson: ClassifierJSON
        enum CodingKeys: String, CodingKey { case outputJson = "output_json" }

        struct ClassifierJSON: Codable, Hashable {
            let groups: [ClassifierGroup]?
        }
    }

    struct ArbiterOutput: Codable, Hashable {
        let summary: String
        let detailedResponse: String
        let text: String?

        enum CodingKeys: String, CodingKey {
            case summary
            case detailedResponse = "detailed_response"
            case text
        }
    }

    struct AdvocateOutput: Codable, Hashable, Identifiable {
        var id: String { "\(advocateKey)-\(provider ?? "")-\(model ?? "")" }

        let advocateKey: String
        let provider: String?
        let model: String?
        let summary: String
        let detailedResponse: String
        let text: String?

        enum CodingKeys: String, CodingKey {
            case advocateKey = "advocate_key"
            case provider, model, summary
            case detailedResponse = "detailed_response"
            case text
        }
    }

    let runId: UUID
    let runIndex: Int?
    let runType: String?
    let promptType: String?
    let arbiterOutput: ArbiterOutput?
    let advocateOutputs: [AdvocateOutput]
    let classifierOutput: ClassifierOutput?
    let mcqDisagreement: Bool?

    enum CodingKeys: String, CodingKey {
        case runId
        case runIndex
        case runType
        case promptType
        case arbiterOutput
        case advocateOutputs
        case classifierOutput
        case mcqDisagreement = "mcq_disagreement"
    }
}
