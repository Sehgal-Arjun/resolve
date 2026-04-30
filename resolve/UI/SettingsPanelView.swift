import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsPanelView: View {
    let onBack: () -> Void

    @ObservedObject private var settings = UserSettingsStore.shared
    @ObservedObject private var authManager = AuthManager.shared

    private enum Route {
        case main
        case editShortcuts
    }

    @State private var route: Route = .main

    private var panelWidth: CGFloat { settings.scaled(620) }
    private var panelHeight: CGFloat { settings.scaled(620) }
    private var cardWidth: CGFloat { settings.scaled(620) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: settings.cornerRadius(16), style: .continuous)
                .fill(settings.panelTranslucency.material)
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(16), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10))
                )
                .shadow(radius: 16)
                .frame(width: cardWidth)

            VStack(alignment: .leading, spacing: 14) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch route {
                        case .main:
                            mainContent
                        case .editShortcuts:
                            editShortcutsContent
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(22)
            .frame(width: cardWidth, height: panelHeight)
            .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius(16), style: .continuous))
        }
        .frame(width: panelWidth, height: panelHeight)
        .tint(settings.resolvedAccentColor)
        .onAppear {
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: !settings.reducedMotion)
        }
        .onChange(of: settings.panelSize) { _ in
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: !settings.reducedMotion)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        accountSection
        appearanceSection
        layoutSection
        defaultsSection
        resolveSection
        polishSection
        behaviorSection
        footerActions
    }

    @ViewBuilder
    private var editShortcutsContent: some View {
        editShortcutsSection
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: handleBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )

            Text(headerTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }

    private var headerTitle: String {
        switch route {
        case .main: return "Settings"
        case .editShortcuts: return "Edit Shortcuts"
        }
    }

    private func handleBack() {
        switch route {
        case .main:
            onBack()
        case .editShortcuts:
            route = .main
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            if let user = authManager.currentUser {
                VStack(spacing: 10) {
                    SettingsValueRow(label: "Name", value: user.name.isEmpty ? "—" : user.name)
                    SettingsValueRow(label: "Email", value: user.email.isEmpty ? "—" : user.email)
                }
            } else {
                Text("Not signed in.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { settings.customAccentColor },
            set: { newColor in
                settings.customAccentHex = newColor.hexString ?? UserSettingsStore.defaultCustomAccentHex
                if settings.accentColorChoice != .custom {
                    settings.accentColorChoice = .custom
                }
            }
        )
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SettingsSection(title: "Appearance") {
            VStack(spacing: 14) {
                SettingsCustomRow(
                    title: "Color scheme",
                    subtitle: "Override the system light/dark mode."
                ) {
                    Picker("", selection: $settings.appearanceColorScheme) {
                        ForEach(AppearanceColorScheme.allCases) { scheme in
                            Text(scheme.displayName).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }

                SettingsCustomRow(
                    title: "Panel translucency",
                    subtitle: "How much of your desktop shows through."
                ) {
                    Picker("", selection: $settings.panelTranslucency) {
                        ForEach(PanelTranslucency.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 280)
                }

                SettingsCustomRow(
                    title: "Accent color",
                    subtitle: "Tints the send button, selected advocates, and controls."
                ) {
                    AccentSwatchRow(
                        selection: $settings.accentColorChoice,
                        customColor: customColorBinding,
                        customColorPreview: settings.customAccentColor
                    )
                }

                SettingsCustomRow(
                    title: "Corner radius",
                    subtitle: "How rounded panels and cards look."
                ) {
                    Picker("", selection: $settings.cornerRadiusStyle) {
                        ForEach(CornerRadiusStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }

                SettingsToggleRow(
                    title: "Reduced motion",
                    subtitle: "Disables panel resize and transition animations.",
                    isOn: $settings.reducedMotion
                )

                Divider()
                    .overlay(Color.white.opacity(0.10))
                    .padding(.vertical, 2)

                SettingsCustomRow(
                    title: "Stance palette",
                    subtitle: "Colors used to label classifier groups on advocate cards."
                ) {
                    Picker("", selection: $settings.stancePalette) {
                        ForEach(StancePalette.allCases) { palette in
                            Text(palette.displayName).tag(palette)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 320)
                }

                SettingsCustomRow(
                    title: "Ambient stance glow",
                    subtitle: "A soft colored halo around the panel matching the dominant stance."
                ) {
                    Picker("", selection: $settings.ambientStanceGlow) {
                        ForEach(AmbientGlow.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }

                SettingsCustomRow(
                    title: "Advocate card density",
                    subtitle: "How much of each advocate's summary you see at a glance."
                ) {
                    Picker("", selection: $settings.advocateCardDensity) {
                        ForEach(AdvocateCardDensity.allCases) { density in
                            Text(density.displayName).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }

                SettingsToggleRow(
                    title: "Keyboard hint chips",
                    subtitle: "Show inline shortcut chips (e.g. ⌘ ⇧ R) next to buttons.",
                    isOn: $settings.showKeyboardHintChips
                )
            }
        }
    }

    // MARK: - Layout

    private var layoutSection: some View {
        SettingsSection(title: "Layout") {
            VStack(spacing: 14) {
                SettingsCustomRow(
                    title: "Panel size",
                    subtitle: "Scales every panel's width and height together."
                ) {
                    Picker("", selection: $settings.panelSize) {
                        ForEach(PanelSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 280)
                }

                SettingsCustomRow(
                    title: "Default panel anchor",
                    subtitle: "Where the floating panel snaps when you summon it."
                ) {
                    Picker("", selection: $settings.panelAnchor) {
                        ForEach(PanelAnchor.allCases) { anchor in
                            Text(anchor.displayName).tag(anchor)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 320)
                }
            }
        }
    }

    // MARK: - Defaults

    private var defaultsSection: some View {
        SettingsSection(title: "Defaults") {
            VStack(spacing: 14) {
                SettingsCustomRow(
                    title: "Default question mode",
                    subtitle: "Pre-selected when you start a new chat."
                ) {
                    Picker("", selection: $settings.defaultProblemType) {
                        Text("General").tag(ProblemType.generalQuestion)
                        Text("Single-Select").tag(ProblemType.multipleChoiceSingle)
                        Text("Multi-Select").tag(ProblemType.multipleChoiceMulti)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 320)
                }

                SettingsCustomRow(
                    title: "Max resolve rounds",
                    subtitle: "How many times you can press Resolve per question."
                ) {
                    HStack(spacing: 6) {
                        Text("\(UserSettingsStore.freePlanResolveRounds)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Text("Free plan")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: settings.cornerRadius(5), style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: settings.cornerRadius(5), style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .opacity(0.6)
                    .help("Max resolve count is currently \(UserSettingsStore.freePlanResolveRounds) on the Free plan. Paid tiers will unlock more.")
                }
            }
        }
    }

    // MARK: - Resolve

    private var resolveSection: some View {
        SettingsSection(title: "Resolve") {
            VStack(spacing: 16) {
                advocateRosterRow
                arbiterToneRow
                SettingsToggleRow(
                    title: "Stance colors",
                    subtitle: "Color advocate cards by which side they took.",
                    isOn: $settings.showStanceColors
                )
            }
        }
    }

    private var advocateRosterRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Active advocates")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("\(settings.enabledAdvocates.count)/\(AdvocateProvider.allCases.count) on")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Text("At least \(UserSettingsStore.minimumActiveAdvocates) must be enabled. Disabled providers won't debate.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                ForEach(AdvocateProvider.allCases) { provider in
                    AdvocateToggleRow(
                        provider: provider,
                        isEnabled: settings.enabledAdvocates.contains(provider),
                        canDisable: settings.enabledAdvocates.count > UserSettingsStore.minimumActiveAdvocates
                            || !settings.enabledAdvocates.contains(provider)
                    ) {
                        settings.toggle(provider)
                    }
                }
            }
        }
    }

    private var arbiterToneRow: some View {
        SettingsCustomRow(
            title: "Arbiter tone",
            subtitle: settings.arbiterStyle.helpText
        ) {
            Picker("", selection: $settings.arbiterStyle) {
                ForEach(ArbiterStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
        }
    }

    // MARK: - Polish

    private var polishSection: some View {
        SettingsSection(title: "Polish") {
            VStack(spacing: 14) {
                SettingsCustomRow(
                    title: "Arbiter summary font",
                    subtitle: "Typeface used for the arbiter's response."
                ) {
                    Picker("", selection: $settings.arbiterFont) {
                        ForEach(ArbiterFont.allCases) { font in
                            Text(font.displayName).tag(font)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }

                SettingsCustomRow(
                    title: "Arbiter summary size",
                    subtitle: "Size of the arbiter's response text."
                ) {
                    Picker("", selection: $settings.arbiterTextSize) {
                        ForEach(ArbiterTextSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                }

                SettingsCustomRow(
                    title: "Bold emphasis style",
                    subtitle: "How **emphasized** segments render in the summary."
                ) {
                    Picker("", selection: $settings.boldEmphasisStyle) {
                        ForEach(BoldEmphasisStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 280)
                }
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        SettingsSection(title: "Behavior") {
            VStack(spacing: 14) {
                SettingsToggleRow(
                    title: "Hide on focus loss",
                    subtitle: "Automatically hide the panel when Resolve is no longer the active app.",
                    isOn: $settings.hideOnFocusLoss
                )

                SettingsCustomRow(
                    title: "Keyboard shortcuts",
                    subtitle: "Customize the global hotkeys Resolve responds to."
                ) {
                    Button {
                        route = .editShortcuts
                    } label: {
                        HStack(spacing: 6) {
                            Text("Edit shortcuts")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }

                SettingsCustomRow(
                    title: "Replay onboarding",
                    subtitle: "Play the introductory tour again from the start."
                ) {
                    // Flipping the flag is enough — RootPanelView observes
                    // it via `.onChange` and re-enters the onboarding flow,
                    // which unmounts this Settings view automatically.
                    Button {
                        settings.hasCompletedOnboarding = false
                    } label: {
                        HStack(spacing: 6) {
                            Text("Replay")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Edit Shortcuts (sub-page)

    private var editShortcutsSection: some View {
        SettingsSection(title: "Keyboard Shortcuts") {
            VStack(spacing: 14) {
                ForEach(resolveCustomizableShortcuts) { spec in
                    SettingsCustomRow(title: spec.title, subtitle: spec.subtitle) {
                        KeyboardShortcuts.Recorder(for: spec.name)
                    }
                }
            }
        }
    }

    // MARK: - About / version

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        return "\(short) (\(build))"
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 12) {
            Text("Resolve · \(appVersionString)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            Button {
                settings.resetToDefaults()
            } label: {
                Text("Reset to defaults")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )

            Button {
                authManager.signOut()
            } label: {
                Text("Sign out")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .fill(Color.red.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

// MARK: - Section + row primitives

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @ObservedObject private var settings = UserSettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)

            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

/// Simple "Label : Value" read-only row.
private struct SettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Title + optional subtitle on the left, arbitrary trailing control on the right.
/// Use this for any setting that needs a custom control (picker, segmented, swatches).
private struct SettingsCustomRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
    }
}

/// Toggle row matching the standard layout.
private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsCustomRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

private struct AdvocateToggleRow: View {
    let provider: AdvocateProvider
    let isEnabled: Bool
    let canDisable: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(provider.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Text("(\(provider.rawValue))")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(!canDisable)
            .opacity(canDisable ? 1.0 : 0.6)
        }
        .padding(.vertical, 4)
    }
}

/// Horizontal swatch picker for accent color. The trailing swatch opens the native
/// `NSColorPanel` (hex / RGB sliders / color wheel / HSB built-in) and feeds picks
/// back through a closure on a small NSObject controller.
private struct AccentSwatchRow: View {
    @Binding var selection: AccentColorChoice
    @Binding var customColor: Color
    let customColorPreview: Color

    @StateObject private var colorPanelController = ColorPanelController()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AccentColorChoice.allCases) { choice in
                if choice == .custom {
                    customSwatch
                } else {
                    Button {
                        selection = choice
                    } label: {
                        swatch(for: choice)
                    }
                    .buttonStyle(.plain)
                    .help(choice.displayName)
                }
            }
        }
        .onAppear {
            colorPanelController.onColorChanged = { newColor in
                customColor = newColor
            }
        }
    }

    @ViewBuilder
    private func swatch(for choice: AccentColorChoice) -> some View {
        let isSelected = selection == choice
        ZStack {
            Circle()
                .fill(fill(for: choice))
                .frame(width: 22, height: 22)

            if choice == .mono {
                Image(systemName: "circle.slash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Circle()
                .stroke(
                    Color.white.opacity(isSelected ? 0.95 : 0.18),
                    lineWidth: isSelected ? 2 : 1
                )
                .frame(width: 24, height: 24)
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
    }

    private var customSwatch: some View {
        let isSelected = selection == .custom
        return Button {
            // Always switch to .custom on tap so flipping back from a preset
            // works even when the user closes the panel without picking.
            selection = .custom
            colorPanelController.show(initialColor: customColor)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red]),
                            center: .center
                        )
                    )
                    .frame(width: 22, height: 22)

                Circle()
                    .fill(customColorPreview)
                    .frame(width: 12, height: 12)

                Circle()
                    .stroke(
                        Color.white.opacity(isSelected ? 0.95 : 0.18),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .frame(width: 24, height: 24)
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Custom — opens the system color picker")
    }

    private func fill(for choice: AccentColorChoice) -> Color {
        if let swatch = choice.presetSwatch {
            return swatch.opacity(0.85)
        }
        return Color.white.opacity(0.15)
    }
}

/// Wraps `NSColorPanel` so a SwiftUI button can drive it with target/action and
/// pipe the picked color back through a closure. Lives as @StateObject on the row.
private final class ColorPanelController: NSObject, ObservableObject {
    var onColorChanged: ((Color) -> Void)?

    func show(initialColor: Color) {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = NSColor(initialColor)
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        let nsColor = sender.color.usingColorSpace(.sRGB) ?? sender.color
        let swiftColor = Color(
            .sRGB,
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            opacity: 1.0
        )
        onColorChanged?(swiftColor)
    }
}
