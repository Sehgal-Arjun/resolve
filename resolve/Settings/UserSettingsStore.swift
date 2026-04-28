import Foundation
import Combine

enum ArbiterStyle: String, CaseIterable, Identifiable {
    case balanced = "balanced"
    case decisive = "decisive"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .decisive: return "Decisive"
        }
    }

    var helpText: String {
        switch self {
        case .balanced:
            return "Lay out trade-offs and let you decide."
        case .decisive:
            return "Pick the strongest position and defend it."
        }
    }
}

extension AdvocateProvider {
    var backendKey: String {
        switch self {
        case .openAI: return "openai"
        case .anthropic: return "anthropic"
        case .gemini: return "gemini"
        case .deepSeek: return "deepseek"
        case .mistral: return "mistral"
        }
    }
}

final class UserSettingsStore: ObservableObject {
    static let shared = UserSettingsStore()

    static let minResolveRounds = 2
    static let maxResolveRoundsCap = 2
    static let freePlanResolveRounds = 2
    static let minimumActiveAdvocates = 2

    private enum Keys {
        static let defaultProblemType = "settings.defaultProblemType"
        static let maxResolveRounds = "settings.maxResolveRounds"
        static let showStanceColors = "settings.showStanceColors"
        static let enabledAdvocates = "settings.enabledAdvocates"
        static let arbiterStyle = "settings.arbiterStyle"
    }

    private let defaults: UserDefaults

    @Published var defaultProblemType: ProblemType {
        didSet {
            defaults.set(defaultProblemType.rawValue, forKey: Keys.defaultProblemType)
        }
    }

    @Published var maxResolveRounds: Int {
        didSet {
            let clamped = max(Self.minResolveRounds, min(Self.maxResolveRoundsCap, maxResolveRounds))
            if clamped != maxResolveRounds {
                maxResolveRounds = clamped
                return
            }
            defaults.set(maxResolveRounds, forKey: Keys.maxResolveRounds)
        }
    }

    @Published var showStanceColors: Bool {
        didSet {
            defaults.set(showStanceColors, forKey: Keys.showStanceColors)
        }
    }

    @Published var enabledAdvocates: Set<AdvocateProvider> {
        didSet {
            if enabledAdvocates.count < Self.minimumActiveAdvocates {
                enabledAdvocates = oldValue
                return
            }
            let raw = enabledAdvocates.map { $0.rawValue }
            defaults.set(raw, forKey: Keys.enabledAdvocates)
        }
    }

    @Published var arbiterStyle: ArbiterStyle {
        didSet {
            defaults.set(arbiterStyle.rawValue, forKey: Keys.arbiterStyle)
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedProblemType = defaults.string(forKey: Keys.defaultProblemType)
        defaultProblemType = storedProblemType.flatMap(ProblemType.init(rawValue:)) ?? .generalQuestion

        let storedRounds = (defaults.object(forKey: Keys.maxResolveRounds) as? Int) ?? 2
        maxResolveRounds = max(Self.minResolveRounds, min(Self.maxResolveRoundsCap, storedRounds))

        showStanceColors = (defaults.object(forKey: Keys.showStanceColors) as? Bool) ?? true

        let storedAdvocates = (defaults.array(forKey: Keys.enabledAdvocates) as? [String]) ?? AdvocateProvider.allCases.map { $0.rawValue }
        let parsed = Set(storedAdvocates.compactMap(AdvocateProvider.init(rawValue:)))
        enabledAdvocates = parsed.count >= Self.minimumActiveAdvocates ? parsed : Set(AdvocateProvider.allCases)

        let storedStyle = defaults.string(forKey: Keys.arbiterStyle)
        arbiterStyle = storedStyle.flatMap(ArbiterStyle.init(rawValue:)) ?? .balanced
    }

    func resetToDefaults() {
        defaultProblemType = .generalQuestion
        maxResolveRounds = 2
        showStanceColors = true
        enabledAdvocates = Set(AdvocateProvider.allCases)
        arbiterStyle = .balanced
    }

    var enabledAdvocateBackendKeys: [String] {
        AdvocateProvider.allCases
            .filter { enabledAdvocates.contains($0) }
            .map { $0.backendKey }
    }

    func toggle(_ provider: AdvocateProvider) {
        if enabledAdvocates.contains(provider) {
            guard enabledAdvocates.count > Self.minimumActiveAdvocates else { return }
            enabledAdvocates.remove(provider)
        } else {
            enabledAdvocates.insert(provider)
        }
    }
}
