import SwiftUI

/// The frosted, rounded panel background shared by every onboarding step.
/// Same visual language as `LandingView` and `AuthenticatedView` so the
/// transition into the post-onboarding home is seamless.
struct OnboardingPanelBackground: View {
    var cornerRadius: CGFloat = 16

    @ObservedObject private var settings = UserSettingsStore.shared

    var body: some View {
        RoundedRectangle(cornerRadius: settings.cornerRadius(cornerRadius), style: .continuous)
            .fill(settings.panelTranslucency.material)
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(cornerRadius), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 14, x: 0, y: 0)
    }
}

/// Keycap that pulses its border + glow with the user's accent color. Used to
/// signal "press me" during the hotkey teaching beat.
struct OnboardingPulseKeycap: View {
    let keys: String
    var pulses: Bool = true

    @ObservedObject private var settings = UserSettingsStore.shared
    @State private var pulse: Bool = false

    var body: some View {
        Text(keys)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(8), style: .continuous)
                    .strokeBorder(
                        settings.resolvedAccentColor.opacity(pulse ? 0.55 : 0.18),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: settings.resolvedAccentColor.opacity(pulse ? 0.32 : 0.0),
                radius: pulse ? 10 : 0
            )
            .scaleEffect(pulse ? 1.04 : 1.0)
            .animation(
                pulses && !settings.reducedMotion
                    ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                    : nil,
                value: pulse
            )
            .onAppear {
                guard pulses, !settings.reducedMotion else { return }
                pulse = true
            }
    }
}

/// A soft, breathing dot rendered with the user's accent color. Used as the
/// quiet status indicator during the "waiting for browser" beat.
struct OnboardingBreathingDot: View {
    var diameter: CGFloat = 24

    @ObservedObject private var settings = UserSettingsStore.shared
    @State private var pulse: Bool = false

    var body: some View {
        Circle()
            .fill(settings.resolvedAccentColor.opacity(pulse ? 0.85 : 0.35))
            .frame(width: diameter, height: diameter)
            .scaleEffect(pulse ? 1.15 : 0.85)
            .animation(
                settings.reducedMotion
                    ? nil
                    : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
    }
}
