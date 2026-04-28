import Foundation
import Combine
import SwiftUI
import AppKit

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

enum AppearanceColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var swiftUIScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum PanelTranslucency: String, CaseIterable, Identifiable {
    case sheer, light, medium, heavy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sheer: return "Sheer"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }

    var material: Material {
        switch self {
        case .sheer: return .ultraThinMaterial
        case .light: return .thinMaterial
        case .medium: return .regularMaterial
        case .heavy: return .thickMaterial
        }
    }
}

enum AccentColorChoice: String, CaseIterable, Identifiable {
    case mono, blue, purple, orange, teal, pink, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mono: return "Mono"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .teal: return "Teal"
        case .pink: return "Pink"
        case .custom: return "Custom"
        }
    }

    /// Built-in swatch. Returns `nil` for mono (no color, use white as tint) and
    /// for custom (caller supplies the live color from store).
    var presetSwatch: Color? {
        switch self {
        case .mono: return nil
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .teal: return .teal
        case .pink: return .pink
        case .custom: return nil
        }
    }
}

extension Color {
    /// Hex parser. Accepts "#RRGGBB" or "#RRGGBBAA" (case insensitive).
    init?(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6 || trimmed.count == 8,
              let value = UInt64(trimmed, radix: 16) else { return nil }
        if trimmed.count == 6 {
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >> 8) & 0xFF) / 255
            let b = Double(value & 0xFF) / 255
            self = Color(red: r, green: g, blue: b)
        } else {
            let r = Double((value >> 24) & 0xFF) / 255
            let g = Double((value >> 16) & 0xFF) / 255
            let b = Double((value >> 8) & 0xFF) / 255
            let a = Double(value & 0xFF) / 255
            self = Color(red: r, green: g, blue: b, opacity: a)
        }
    }

    /// Returns "#RRGGBB" using the sRGB color space.
    var hexString: String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

enum CornerRadiusStyle: String, CaseIterable, Identifiable {
    case sharp, standard, soft

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sharp: return "Sharp"
        case .standard: return "Standard"
        case .soft: return "Soft"
        }
    }

    var scale: CGFloat {
        switch self {
        case .sharp: return 0.4
        case .standard: return 1.0
        case .soft: return 1.5
        }
    }
}

enum StancePalette: String, CaseIterable, Identifiable {
    case vibrant, pastel, highContrast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vibrant: return "Vibrant"
        case .pastel: return "Pastel"
        case .highContrast: return "Contrast"
        }
    }

    /// Five colors used to label classifier groups in stance order.
    var colors: [Color] {
        switch self {
        case .vibrant:
            return [.blue, .purple, .orange, .teal, .pink]
        case .pastel:
            // Saturation-pumped pastels — distinct hues that still read soft on
            // both light and dark material.
            return [
                Color(red: 0.42, green: 0.68, blue: 1.00), // sky blue
                Color(red: 0.74, green: 0.55, blue: 1.00), // lavender
                Color(red: 1.00, green: 0.66, blue: 0.40), // peach
                Color(red: 0.40, green: 0.92, blue: 0.78), // mint
                Color(red: 1.00, green: 0.55, blue: 0.78)  // rose
            ]
        case .highContrast:
            return [
                Color(red: 1.00, green: 0.20, blue: 0.20),
                Color(red: 1.00, green: 0.85, blue: 0.10),
                Color(red: 0.10, green: 0.85, blue: 0.30),
                Color(red: 0.10, green: 0.55, blue: 1.00),
                Color(red: 1.00, green: 0.20, blue: 0.85)
            ]
        }
    }
}

enum AmbientGlow: String, CaseIterable, Identifiable {
    case off, subtle, pronounced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .subtle: return "Subtle"
        case .pronounced: return "Pronounced"
        }
    }

    /// Stroke width for the colored border that hugs the outer panel.
    var borderWidth: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 1.5
        case .pronounced: return 3.0
        }
    }

    var opacity: Double {
        switch self {
        case .off: return 0
        case .subtle: return 0.55
        case .pronounced: return 0.90
        }
    }

    var isOn: Bool { self != .off }
}

enum PanelSize: String, CaseIterable, Identifiable {
    case compact, comfortable, spacious

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .spacious: return "Spacious"
        }
    }

    /// Multiplier applied to every panel's width and height.
    var scale: CGFloat {
        switch self {
        case .compact: return 0.85
        case .comfortable: return 1.0
        case .spacious: return 1.15
        }
    }
}

enum PanelAnchor: String, CaseIterable, Identifiable {
    case center, lastPosition

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .center: return "Center"
        case .lastPosition: return "Last position"
        }
    }
}

enum AdvocateCardDensity: String, CaseIterable, Identifiable {
    case compact, cozy, detailed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .cozy: return "Cozy"
        case .detailed: return "Detailed"
        }
    }

    /// `lineLimit` for the summary on the standard advocate card.
    var summaryLineLimit: Int {
        switch self {
        case .compact: return 1
        case .cozy: return 2
        case .detailed: return 4
        }
    }

    /// `lineLimit` for the thesis card used in general-question mode.
    var thesisLineLimit: Int {
        switch self {
        case .compact: return 3
        case .cozy: return 5
        case .detailed: return 8
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
        static let appearanceColorScheme = "settings.appearanceColorScheme"
        static let panelTranslucency = "settings.panelTranslucency"
        static let accentColorChoice = "settings.accentColorChoice"
        static let customAccentHex = "settings.customAccentHex"
        static let cornerRadiusStyle = "settings.cornerRadiusStyle"
        static let reducedMotion = "settings.reducedMotion"
        static let stancePalette = "settings.stancePalette"
        static let ambientStanceGlow = "settings.ambientStanceGlow"
        static let advocateCardDensity = "settings.advocateCardDensity"
        static let showKeyboardHintChips = "settings.showKeyboardHintChips"
        static let panelSize = "settings.panelSize"
        static let panelAnchor = "settings.panelAnchor"
        static let lastPanelFrame = "settings.lastPanelFrame"
    }

    static let defaultCustomAccentHex = "#3B82F6"

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

    @Published var appearanceColorScheme: AppearanceColorScheme {
        didSet {
            defaults.set(appearanceColorScheme.rawValue, forKey: Keys.appearanceColorScheme)
            applyAppearance()
        }
    }

    @Published var panelTranslucency: PanelTranslucency {
        didSet {
            defaults.set(panelTranslucency.rawValue, forKey: Keys.panelTranslucency)
        }
    }

    @Published var accentColorChoice: AccentColorChoice {
        didSet {
            defaults.set(accentColorChoice.rawValue, forKey: Keys.accentColorChoice)
        }
    }

    @Published var customAccentHex: String {
        didSet {
            defaults.set(customAccentHex, forKey: Keys.customAccentHex)
        }
    }

    @Published var cornerRadiusStyle: CornerRadiusStyle {
        didSet {
            defaults.set(cornerRadiusStyle.rawValue, forKey: Keys.cornerRadiusStyle)
        }
    }

    @Published var reducedMotion: Bool {
        didSet {
            defaults.set(reducedMotion, forKey: Keys.reducedMotion)
        }
    }

    @Published var stancePalette: StancePalette {
        didSet {
            defaults.set(stancePalette.rawValue, forKey: Keys.stancePalette)
        }
    }

    @Published var ambientStanceGlow: AmbientGlow {
        didSet {
            defaults.set(ambientStanceGlow.rawValue, forKey: Keys.ambientStanceGlow)
        }
    }

    @Published var advocateCardDensity: AdvocateCardDensity {
        didSet {
            defaults.set(advocateCardDensity.rawValue, forKey: Keys.advocateCardDensity)
        }
    }

    @Published var showKeyboardHintChips: Bool {
        didSet {
            defaults.set(showKeyboardHintChips, forKey: Keys.showKeyboardHintChips)
        }
    }

    @Published var panelSize: PanelSize {
        didSet {
            defaults.set(panelSize.rawValue, forKey: Keys.panelSize)
        }
    }

    @Published var panelAnchor: PanelAnchor {
        didSet {
            defaults.set(panelAnchor.rawValue, forKey: Keys.panelAnchor)
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

        let storedScheme = defaults.string(forKey: Keys.appearanceColorScheme)
        appearanceColorScheme = storedScheme.flatMap(AppearanceColorScheme.init(rawValue:)) ?? .system

        let storedTranslucency = defaults.string(forKey: Keys.panelTranslucency)
        panelTranslucency = storedTranslucency.flatMap(PanelTranslucency.init(rawValue:)) ?? .sheer

        let storedAccent = defaults.string(forKey: Keys.accentColorChoice)
        accentColorChoice = storedAccent.flatMap(AccentColorChoice.init(rawValue:)) ?? .mono

        customAccentHex = defaults.string(forKey: Keys.customAccentHex) ?? Self.defaultCustomAccentHex

        let storedCorner = defaults.string(forKey: Keys.cornerRadiusStyle)
        cornerRadiusStyle = storedCorner.flatMap(CornerRadiusStyle.init(rawValue:)) ?? .standard

        reducedMotion = (defaults.object(forKey: Keys.reducedMotion) as? Bool) ?? false

        let storedStance = defaults.string(forKey: Keys.stancePalette)
        stancePalette = storedStance.flatMap(StancePalette.init(rawValue:)) ?? .vibrant

        let storedGlow = defaults.string(forKey: Keys.ambientStanceGlow)
        ambientStanceGlow = storedGlow.flatMap(AmbientGlow.init(rawValue:)) ?? .off

        let storedDensity = defaults.string(forKey: Keys.advocateCardDensity)
        advocateCardDensity = storedDensity.flatMap(AdvocateCardDensity.init(rawValue:)) ?? .cozy

        showKeyboardHintChips = (defaults.object(forKey: Keys.showKeyboardHintChips) as? Bool) ?? true

        let storedSize = defaults.string(forKey: Keys.panelSize)
        panelSize = storedSize.flatMap(PanelSize.init(rawValue:)) ?? .comfortable

        // Migrate the old "topCenter" / "bottomCenter" raw values to the unified "center".
        let rawAnchor = defaults.string(forKey: Keys.panelAnchor)
        let normalizedAnchor: String? = {
            switch rawAnchor {
            case "topCenter", "bottomCenter": return "center"
            default: return rawAnchor
            }
        }()
        panelAnchor = normalizedAnchor.flatMap(PanelAnchor.init(rawValue:)) ?? .center

        applyAppearance()
    }

    func resetToDefaults() {
        defaultProblemType = .generalQuestion
        maxResolveRounds = 2
        showStanceColors = true
        enabledAdvocates = Set(AdvocateProvider.allCases)
        arbiterStyle = .balanced
        appearanceColorScheme = .system
        panelTranslucency = .sheer
        accentColorChoice = .mono
        customAccentHex = Self.defaultCustomAccentHex
        cornerRadiusStyle = .standard
        reducedMotion = false
        stancePalette = .vibrant
        ambientStanceGlow = .off
        advocateCardDensity = .cozy
        showKeyboardHintChips = true
        panelSize = .comfortable
        panelAnchor = .center
    }

    /// Multiplies a base panel dimension by the user-selected size scale.
    func scaled(_ base: CGFloat) -> CGFloat {
        base * panelSize.scale
    }

    /// Persisted last frame for the primary panel — used when `panelAnchor`
    /// is `.lastPosition`. Returns nil if nothing's been persisted yet.
    var persistedPrimaryPanelFrame: NSRect? {
        guard let raw = defaults.string(forKey: Keys.lastPanelFrame), !raw.isEmpty else { return nil }
        let rect = NSRectFromString(raw)
        return rect == .zero ? nil : rect
    }

    func setPersistedPrimaryPanelFrame(_ frame: NSRect) {
        defaults.set(NSStringFromRect(frame), forKey: Keys.lastPanelFrame)
    }

    /// Resolved accent color, taking the custom hex into account.
    var customAccentColor: Color {
        Color(hex: customAccentHex) ?? Color(hex: Self.defaultCustomAccentHex) ?? .blue
    }

    /// Color used for tints/highlights. Mono falls back to white so opacity-tinted
    /// surfaces look identical to the original UI.
    var resolvedAccentColor: Color {
        switch accentColorChoice {
        case .custom: return customAccentColor
        case .mono: return .white
        default:
            return accentColorChoice.presetSwatch ?? .white
        }
    }

    /// Color used to render the swatch dot in the picker.
    var resolvedAccentSwatch: Color {
        switch accentColorChoice {
        case .custom: return customAccentColor
        default:
            return accentColorChoice.presetSwatch ?? Color.white.opacity(0.15)
        }
    }

    /// Pushes the chosen color scheme into AppKit so the entire app (including
    /// chrome) respects it. SwiftUI's `.preferredColorScheme(nil)` doesn't reliably
    /// revert to system after a non-nil value, and individual `NSWindow.appearance`
    /// values override `NSApp.appearance` — so we both set the app-level appearance
    /// and clear every window's local override on every change.
    func applyAppearance() {
        let scheme = appearanceColorScheme
        let work: () -> Void = {
            let target: NSAppearance?
            switch scheme {
            case .system:
                target = nil
            case .light:
                target = NSAppearance(named: .aqua)
            case .dark:
                target = NSAppearance(named: .darkAqua)
            }
            NSApp.appearance = target
            // Clear per-window overrides so windows fall back to NSApp.appearance,
            // which itself falls back to the OS preference when nil. Without this,
            // a previously forced .aqua/.darkAqua sticks on existing panels.
            for window in NSApp.windows {
                window.appearance = nil
                window.invalidateShadow()
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// Multiplies a base corner radius by the user-selected style. Use everywhere
    /// you currently pass a hard-coded radius so the whole UI scales together.
    func cornerRadius(_ base: CGFloat) -> CGFloat {
        max(2, base * cornerRadiusStyle.scale)
    }

    /// Returns the chosen animation, or nil if reduced motion is on.
    func animation(_ animation: Animation) -> Animation? {
        reducedMotion ? nil : animation
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
