import Foundation

struct LabeledMCQ: Decodable {
    let ok: Bool
    let reason: String?
    let question_stem: String?
    let options: [LabeledOption]?
}

struct LabeledOption: Decodable {
    let label: String   // "A"..."Z"
    let text: String
}
