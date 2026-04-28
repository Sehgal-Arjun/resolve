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
    let runId: UUID?
    let runStatus: String?
    let status: String?
    let latestRunId: UUID?
    let latestRunStatus: String?
    let latestRunIndex: Int?
    let latestRunType: String?
    let latestCompletedRunId: UUID?
    let latestCompletedRunStatus: String?
    let latestCompletedRunIndex: Int?
    let latestCompletedRunType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role, content
        case createdAt = "created_at"
        case promptType = "prompt_type"
        case runId = "run_id"
        case runStatus = "run_status"
        case status
        case latestRunId = "latest_run_id"
        case latestRunStatus = "latest_run_status"
        case latestRunIndex = "latest_run_index"
        case latestRunType = "latest_run_type"
        case latestCompletedRunId = "latest_completed_run_id"
        case latestCompletedRunStatus = "latest_completed_run_status"
        case latestCompletedRunIndex = "latest_completed_run_index"
        case latestCompletedRunType = "latest_completed_run_type"
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

    struct RunMetadata: Codable, Hashable {
        let id: UUID
        let runIndex: Int?
        let runType: String?
        let promptType: String?
        let status: String?
        let errorText: String?

        enum CodingKeys: String, CodingKey {
            case id
            case runIndex = "run_index"
            case runType = "run_type"
            case promptType = "prompt_type"
            case status
            case errorText = "error_text"
        }
    }

    struct ClassifierOutput: Codable, Hashable {
        let outputJson: ClassifierJSON
        let finishedAt: Date?
        enum CodingKeys: String, CodingKey {
            case outputJson = "output_json"
            case finishedAt = "finished_at"
        }

        struct ClassifierJSON: Codable, Hashable {
            let groups: [ClassifierGroup]?
        }
    }

    struct ArbiterOutput: Codable, Hashable {
        let summary: String?
        let detailedResponse: String?
        let content: String?
        let text: String?
        let outputJson: ArbiterOutputJSON?
        let finishedAt: Date?

        enum CodingKeys: String, CodingKey {
            case summary
            case detailedResponse = "detailed_response"
            case content
            case text
            case outputJson = "output_json"
            case finishedAt = "finished_at"
        }

        struct ArbiterOutputJSON: Codable, Hashable {}
    }

    struct AdvocateOutput: Codable, Hashable, Identifiable {
        var id: String { "\(advocateKey)-\(provider ?? "")-\(model ?? "")" }

        let advocateKey: String
        let provider: String?
        let model: String?
        let summary: String?
        let detailedResponse: String?
        let content: String?
        let text: String?
        let finishedAt: Date?

        enum CodingKeys: String, CodingKey {
            case advocateKey = "advocate_key"
            case provider, model, summary
            case detailedResponse = "detailed_response"
            case content
            case text
            case finishedAt = "finished_at"
        }
    }

    struct LabelOutput: Codable, Hashable {
        let outputJson: LabelOutputJSON?
        let finishedAt: Date?

        enum CodingKeys: String, CodingKey {
            case outputJson = "output_json"
            case finishedAt = "finished_at"
        }

        struct LabelOutputJSON: Codable, Hashable {}
    }

    let runId: UUID
    let runIndex: Int?
    let runType: String?
    let promptType: String?
    let status: String?
    let errorText: String?
    let arbiterOutput: ArbiterOutput?
    let advocateOutputs: [AdvocateOutput]
    let classifierOutput: ClassifierOutput?
    let labelOutput: LabelOutput?
    let mcqDisagreement: Bool?

    enum EnvelopeKeys: String, CodingKey {
        case run
        case arbiterOutput = "arbiter_outputs"
        case advocateOutputs = "advocate_outputs"
        case classifierOutput = "classifier_outputs"
        case labelOutput = "label_outputs"
        case mcqDisagreement = "mcq_disagreement"
    }

    enum LegacyKeys: String, CodingKey {
        case runId
        case runIndex
        case runType
        case promptType
        case arbiterOutput
        case advocateOutputs
        case classifierOutput
        case mcqDisagreement = "mcq_disagreement"
    }

    init(from decoder: Decoder) throws {
        let envelope = try decoder.container(keyedBy: EnvelopeKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)

        if envelope.contains(.run) {
            let run = try envelope.decode(RunMetadata.self, forKey: .run)
            runId = run.id
            runIndex = run.runIndex
            runType = run.runType
            promptType = run.promptType
            status = run.status
            errorText = run.errorText
        } else {
            runId = try legacy.decode(UUID.self, forKey: .runId)
            runIndex = try legacy.decodeIfPresent(Int.self, forKey: .runIndex)
            runType = try legacy.decodeIfPresent(String.self, forKey: .runType)
            promptType = try legacy.decodeIfPresent(String.self, forKey: .promptType)
            status = nil
            errorText = nil
        }

        let legacyArbiter = try legacy.decodeIfPresent(ArbiterOutput.self, forKey: .arbiterOutput)
        arbiterOutput = try envelope.decodeIfPresent(ArbiterOutput.self, forKey: .arbiterOutput) ?? legacyArbiter

        let legacyAdvocates = try legacy.decodeIfPresent([AdvocateOutput].self, forKey: .advocateOutputs)
        advocateOutputs = (try envelope.decodeIfPresent([AdvocateOutput].self, forKey: .advocateOutputs))
            ?? legacyAdvocates
            ?? []

        let legacyClassifier = try legacy.decodeIfPresent(ClassifierOutput.self, forKey: .classifierOutput)
        classifierOutput = try envelope.decodeIfPresent(ClassifierOutput.self, forKey: .classifierOutput) ?? legacyClassifier

        labelOutput = try envelope.decodeIfPresent(LabelOutput.self, forKey: .labelOutput)

        let legacyMcq = try legacy.decodeIfPresent(Bool.self, forKey: .mcqDisagreement)
        mcqDisagreement = try envelope.decodeIfPresent(Bool.self, forKey: .mcqDisagreement) ?? legacyMcq
    }
}
