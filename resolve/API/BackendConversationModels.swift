import Foundation

// MARK: - Conversation Endpoints Models

struct Conversation: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String?
    let resolveCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case resolveCount = "resolve_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MessageTranscriptRow: Codable, Identifiable, Hashable {
    let id: UUID
    let conversationId: UUID
    let role: String
    let content: String
    let createdAt: Date

    // Latest run info (nullable)
    let runId: UUID?
    let runIndex: Int?
    let runType: String?
    let promptType: String?
    let status: String?
    let finishedAt: Date?

    let arbiterText: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
        case runId = "run_id"
        case runIndex = "run_index"
        case runType = "run_type"
        case promptType = "prompt_type"
        case status
        case finishedAt = "finished_at"
        case arbiterText = "arbiter_text"
    }
}

// Message row returned from POST /conversations/:id/messages (DB row)
// Keys are snake_case and do not include transcript-only fields like arbiter_text.
struct MessageRow: Codable, Identifiable, Hashable {
    let id: UUID
    let conversationId: UUID
    let role: String
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
    }
}

struct ConversationDetail: Codable, Hashable {
    let conversation: Conversation
    let messages: [MessageTranscriptRow]
}

struct PostMessageResponse: Codable, Hashable {
    let message: MessageRow
    let run: RunResult
}

struct RunResult: Codable, Hashable {
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
            case provider
            case model
            case summary
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

    // Backend returns camelCase keys for run payloads.
    enum CodingKeys: String, CodingKey {
        case runId
        case runIndex
        case runType
        case promptType
        case arbiterOutput
        case advocateOutputs
    }
}

// Debug response is not currently consumed by UI; keep it flexible.
// The backend returns a JSON object; this type can decode arbitrary JSON.

enum JSONValue: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

typealias RunDebugResponse = JSONValue
