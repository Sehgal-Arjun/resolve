import Foundation

struct StanceGroup {
    let stanceID: String        // e.g. "S1", "S2"
    let members: [AdvocateProvider]
    let stanceSummary: String   // short human-readable description
}
