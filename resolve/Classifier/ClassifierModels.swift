import Foundation

public struct ClassifierGroup: Codable, Hashable, Identifiable {
    public var id: String { stanceId }
    public let stanceId: String
    public let members: [String]
    public let stanceSummary: String?

    enum CodingKeys: String, CodingKey {
        case stanceId = "stance_id"
        case members
        case stanceSummary = "stance_summary"
    }
}
