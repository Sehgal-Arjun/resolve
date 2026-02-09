import Foundation

func classifyStances(
    problemType: ProblemType,
    question: String,
    advocateResults: [AdvocateResult]
) async -> [StanceGroup] {
    switch problemType {
    case .multipleChoiceSingle, .multipleChoiceMulti:
        return classifyMCQStances(problemType: problemType, advocateResults: advocateResults)
    case .generalQuestion, .comparison:
        return await classifyNarrativeStances(question: question, advocateResults: advocateResults)
    }
}

private func classifyMCQStances(
    problemType: ProblemType,
    advocateResults: [AdvocateResult]
) -> [StanceGroup] {
    // 1) Normalize summaries to canonical key
    func canonicalKey(from summary: String) -> String {
        let parts = summary
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }

        if parts.isEmpty {
            return "∅"
        }

        let sorted = parts.sorted()
        return sorted.joined(separator: ", ")
    }

    let providerOrder = AdvocateProvider.allCases

    let grouped = Dictionary(grouping: advocateResults) { result in
        canonicalKey(from: result.summary)
    }

    let sortedKeys = grouped.keys.sorted()

    return sortedKeys.enumerated().map { index, key in
        let members = (grouped[key] ?? [])
            .map { $0.provider }
            .sorted {
                (providerOrder.firstIndex(of: $0) ?? Int.max) < (providerOrder.firstIndex(of: $1) ?? Int.max)
            }

        return StanceGroup(
            stanceID: "S\(index + 1)",
            members: members,
            stanceSummary: key
        )
    }
}

private func classifyNarrativeStances(
    question: String,
    advocateResults: [AdvocateResult]
) async -> [StanceGroup] {
    let providerOrder = AdvocateProvider.allCases

    guard let output = await ClassifierClient.classifyNarrative(question: question, summaries: advocateResults) else {
        return fallbackOneGroupPerAdvocate(advocateResults: advocateResults)
    }

    // Validate: every provider appears exactly once
    let inputProviders = advocateResults.map { $0.provider.rawValue }
    let inputSet = Set(inputProviders)

    var seen: [String: Int] = [:]
    for group in output.groups {
        for member in group.members {
            seen[member, default: 0] += 1
        }
    }

    let allExactlyOnce = inputSet.allSatisfy { seen[$0] == 1 }
    let noUnknownMembers = Set(seen.keys).isSubset(of: inputSet)

    guard allExactlyOnce, noUnknownMembers else {
        return fallbackOneGroupPerAdvocate(advocateResults: advocateResults)
    }

    // Convert to StanceGroup and stabilize ordering
    let byStanceID = output.groups.sorted { $0.stance_id < $1.stance_id }

    var stanceGroups: [StanceGroup] = []
    stanceGroups.reserveCapacity(byStanceID.count)

    for (index, group) in byStanceID.enumerated() {
        let members = group.members
            .compactMap { AdvocateProvider(rawValue: $0) }
            .sorted {
                (providerOrder.firstIndex(of: $0) ?? Int.max) < (providerOrder.firstIndex(of: $1) ?? Int.max)
            }

        // Ensure stance IDs are stable S1, S2, ...
        stanceGroups.append(
            StanceGroup(
                stanceID: "S\(index + 1)",
                members: members,
                stanceSummary: group.stance_summary
            )
        )
    }

    return stanceGroups
}

private func fallbackOneGroupPerAdvocate(
    advocateResults: [AdvocateResult]
) -> [StanceGroup] {
    let providerOrder = AdvocateProvider.allCases

    let sorted = advocateResults.sorted {
        (providerOrder.firstIndex(of: $0.provider) ?? Int.max) < (providerOrder.firstIndex(of: $1.provider) ?? Int.max)
    }

    return sorted.enumerated().map { index, result in
        StanceGroup(
            stanceID: "S\(index + 1)",
            members: [result.provider],
            stanceSummary: result.summary
        )
    }
}
