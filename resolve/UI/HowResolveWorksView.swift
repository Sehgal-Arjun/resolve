import SwiftUI

struct HowResolveWorksView: View {
    let onBack: () -> Void
    private var cardWidth: CGFloat { settings.scaled(520) }
    private var panelWidth: CGFloat { settings.scaled(520) }
    private var panelHeight: CGFloat { settings.scaled(410) }
    private let cardCornerRadius: CGFloat = 16

    @ObservedObject private var settings = UserSettingsStore.shared

    @State private var isBackButtonHovering = false

    var body: some View {
        ZStack {
            background
            scrollContent
        }
        .frame(width: panelWidth, height: panelHeight)
        .onAppear {
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: !settings.reducedMotion)
        }
        .onChange(of: settings.panelSize) { _ in
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: !settings.reducedMotion)
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
            .fill(settings.panelTranslucency.material)
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 14, x: 0, y: 0)
            .frame(width: cardWidth)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                introBlurb
                stepCards
            }
            .padding(.top, 22)
            .padding(.bottom, 22)
            .padding(.horizontal, 22)
            .frame(width: cardWidth, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
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
            .keyboardShortcut("b", modifiers: .command)
            .help("Go home (⌘ B)")
            .onHover { isBackButtonHovering = $0 }
            .overlay(alignment: .top) {
                if settings.showKeyboardHintChips {
                    ResolveKeyHintChip("⌘ B")
                        .fixedSize()
                        .offset(y: -20)
                        .opacity(isBackButtonHovering ? 1 : 0)
                        .animation(.easeOut(duration: 0.12), value: isBackButtonHovering)
                        .allowsHitTesting(false)
                }
            }

            Text("How Resolve Works")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            replayTutorialButton
        }
    }

    /// Same visual as the Replay button in Settings. Flipping
    /// `hasCompletedOnboarding` is enough; RootPanelView observes it
    /// via `.onChange` and re-enters the onboarding flow, which
    /// unmounts this view automatically.
    private var replayTutorialButton: some View {
        Button {
            settings.hasCompletedOnboarding = false
        } label: {
            HStack(spacing: 6) {
                Text("Replay Demo")
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
        .help("Replay the onboarding tour")
    }

    // MARK: - Intro

    private var introBlurb: some View {
        Text("Most AI tools hand you one model's voice. Resolve interrogates several at once, exposes where they disagree, and tells you why, so you're never trusting a single answer blindly.")
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepCards: some View {
        stepCard(
            number: 1,
            title: "You ask anything",
            body: "Pose any question. Open-ended, technical, strategic, half-formed. Resolve fans the exact same prompt out to multiple frontier models in parallel."
        )

        stepCard(
            number: 2,
            title: "Models respond independently",
            body: "Claude, GPT, Gemini, and friends each answer in isolation. No blending, no consensus theater. Their raw reasoning stays intact, side by side, ready to inspect."
        )

        stepCard(
            number: 3,
            title: "The Arbiter dissects the disagreement",
            body: "Resolve compares every response and traces the exact fault lines. If the models agree, the synthesis stays terse. If they diverge, the Arbiter shows you where and why.",
            bullets: [
                "Real consensus, not cosmetic overlap",
                "Hidden assumptions and blind spots",
                "Each model's strongest reasoning path",
                "Whether the disagreement actually matters"
            ]
        )

        stepCard(
            number: 4,
            title: "You get a precision-tuned synthesis",
            body: "An analysis, not an average. A distilled summary that surfaces what's shared, where the cracks are, and which reasoning is worth leaning on.",
            bullets: [
                "What most models converge on",
                "Where they split, and over what",
                "The strongest threads of argument",
                "What still needs your judgment"
            ]
        )

        stepCard(
            number: 5,
            title: "You decide",
            body: "Resolve doesn't replace your judgment. It hands you structured signal across the smartest systems alive, then steps aside."
        )
    }

    @ViewBuilder
    private func stepCard(
        number: Int,
        title: String,
        body: String,
        bullets: [String] = []
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            stepBadge(number: number)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(body)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                                Text(bullet)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.system(size: 12.5, weight: .regular))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func stepBadge(number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: 26, height: 26)
            .background(
                Circle().fill(settings.resolvedAccentColor.opacity(0.18))
            )
            .overlay(
                Circle().strokeBorder(settings.resolvedAccentColor.opacity(0.45), lineWidth: 1)
            )
    }
}
