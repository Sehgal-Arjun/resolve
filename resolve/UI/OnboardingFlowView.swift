import SwiftUI

/// First-launch onboarding flow. Walks the user through:
///   1. The R unfurling into the panel
///   2. ⌘ ; — the global hide/show toggle (taught by doing)
///   3. Sign in / sign up
///   4. A welcome moment after auth
///   5. Three-beat overview of how Resolve actually works
///
/// Driven by a single `Step` enum so the panel can morph through every state
/// in the same animated frame container the rest of the app uses.
struct OnboardingFlowView: View {
    /// The morph splits into two distinct beats so the panel growth and the
    /// header settling don't fight each other:
    ///   arrival → unfurled : panel grows in all directions, R stays dead-
    ///                        center the whole time, content stays hidden.
    ///   unfurled → hotkey  : panel is at full size, the R slides into the
    ///                        header position and the body fades in.
    enum Step: Equatable {
        case arrival          // small panel, R 56pt centered
        case unfurled         // panel at full size, R 56pt still centered
        case hotkey           // R 28pt in header, body visible
        case hotkeyHidden     // panel was hidden by user; waiting for re-show
        case hotkeyResolved   // user toggled successfully — celebration beat
        case signIn           // sign-in / sign-up CTA
        case signingIn        // browser sheet open, breathing dot
        case welcome          // post-auth "Welcome, [name]"
        case concept          // three-beat product explainer
    }

    /// Called when the user finishes (or skips) onboarding. The Bool is
    /// `true` when the primary CTA was used ("Try Resolve") and the caller
    /// should drop the user straight into a new chat. `false` means the user
    /// took the soft exit ("Skip") and should land on the home screen.
    let onComplete: (Bool) -> Void

    @ObservedObject private var settings = UserSettingsStore.shared
    @EnvironmentObject private var authManager: AuthManager

    @State private var step: Step = .arrival
    @State private var togglePaletteToken: NSObjectProtocol?
    @State private var diveInToken: NSObjectProtocol?
    @State private var conceptRevealCount: Int = 0
    @State private var arrivalDidStart: Bool = false

    private let cardCornerRadius: CGFloat = 16
    /// Single source of truth for the morph duration. The SwiftUI `.frame`
    /// inside this view animates at this exact value while the AppKit panel's
    /// `setSize` is driven with the same duration + matching ease-in-out
    /// timing — keeping the inner content perfectly aligned with the outer
    /// panel chrome through the entire transition.
    private let morphDuration: Double = 0.45

    /// Panel sizes are hand-tuned to fit each step's content snugly. The
    /// rule is "panel height ≈ content height + padding" — the only step
    /// that intentionally has more height than content is `.arrival`, which
    /// is square so the standalone R reads as a logo and not a caption.
    private var panelSize: CGSize {
        switch step {
        case .arrival:
            return CGSize(width: settings.scaled(160), height: settings.scaled(160))
        case .unfurled, .hotkey, .hotkeyHidden:
            return CGSize(width: settings.scaled(480), height: settings.scaled(215))
        case .hotkeyResolved:
            return CGSize(width: settings.scaled(480), height: settings.scaled(225))
        case .signIn:
            return CGSize(width: settings.scaled(480), height: settings.scaled(250))
        case .signingIn:
            return CGSize(width: settings.scaled(480), height: settings.scaled(210))
        case .welcome:
            return CGSize(width: settings.scaled(480), height: settings.scaled(190))
        case .concept:
            return CGSize(width: settings.scaled(520), height: settings.scaled(345))
        }
    }

    private let contentPadding: CGFloat = 22
    private let arrivalLogoSize: CGFloat = 56
    private let headerLogoSize: CGFloat = 28

    /// Size of the persistent R mark for the current step. Big and centered
    /// during the unfurl; standard 28pt once it settles into the header.
    private var logoSize: CGFloat {
        switch step {
        case .arrival, .unfurled:
            return arrivalLogoSize
        default:
            return headerLogoSize
        }
    }

    /// Where the R should sit in the panel for the current step. During the
    /// arrival/unfurled beats we compute this against the panel's *actual*
    /// current size (read from a GeometryReader proxy), not the target size
    /// derived from `step`. That way the R rides the live panel center as
    /// AppKit animates the panel.frame, with no chance of SwiftUI's idea of
    /// "panel center" drifting away from the panel chrome's idea. Once the
    /// unfurl is done we fall back to a fixed top-left header coordinate and
    /// SwiftUI animates the slide.
    private func currentLogoCenter(in size: CGSize) -> CGPoint {
        switch step {
        case .arrival, .unfurled:
            return CGPoint(x: size.width / 2, y: size.height / 2)
        default:
            let inset = contentPadding + headerLogoSize / 2
            return CGPoint(x: inset, y: inset)
        }
    }

    /// True while the R should still be sitting at the panel's center. Step
    /// content stays hidden through these beats.
    private var isUnfurling: Bool {
        step == .arrival || step == .unfurled
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OnboardingPanelBackground(cornerRadius: cardCornerRadius)

                // Step body — title, copy, buttons. Hidden through arrival
                // and unfurled; the persistent R is doing all the work then.
                // Fades in once the panel has finished growing.
                content
                    .padding(contentPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous))
                    .opacity(isUnfurling ? 0 : 1)

                // R logo. During the unfurl beats we read the panel's actual
                // current size out of the GeometryReader and pin the R to its
                // live center, so the R stays exactly aligned with whatever
                // the AppKit panel is doing — no risk of SwiftUI drifting
                // ahead of or behind the panel chrome during the resize.
                // After unfurling, we fall back to a fixed top-left coordinate
                // and SwiftUI animates the slide into the header.
                ResolveLogoMark(size: logoSize)
                    .position(currentLogoCenter(in: proxy.size))
                    .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // No explicit `.frame(width:height:)` here — the SwiftUI hierarchy
        // fills the panel's `contentView`, whose frame is driven entirely by
        // the AppKit `setFrame` animation. That makes the panel's resize the
        // single source of truth for size, which prevents the panel chrome
        // from drifting against the inner content during the morph.
        .tint(settings.resolvedAccentColor)
        .onAppear {
            applyPanelSize(animated: false)
            registerToggleListener()
            registerDiveInListener()
            startArrivalSequenceIfNeeded()
        }
        .onChange(of: step) { _, _ in
            applyPanelSize(animated: !settings.reducedMotion)
        }
        .onChange(of: authManager.state) { _, newValue in
            handleAuthStateChange(newValue)
        }
        .onChange(of: settings.panelSize) { _, _ in
            applyPanelSize(animated: !settings.reducedMotion)
        }
        .onDisappear {
            if let token = togglePaletteToken {
                NotificationCenter.default.removeObserver(token)
                togglePaletteToken = nil
            }
            if let token = diveInToken {
                NotificationCenter.default.removeObserver(token)
                diveInToken = nil
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .arrival, .unfurled:
            // The persistent R overlay handles these beats; body stays empty.
            Color.clear
        case .hotkey, .hotkeyHidden:
            hotkeyContent
                .transition(.opacity)
        case .hotkeyResolved:
            hotkeyResolvedContent
                .transition(.opacity)
        case .signIn:
            signInContent
                .transition(.opacity)
        case .signingIn:
            signingInContent
                .transition(.opacity)
        case .welcome:
            welcomeContent
                .transition(.opacity)
        case .concept:
            conceptContent
                .transition(.opacity)
        }
    }

    private var hotkeyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            VStack(alignment: .leading, spacing: 6) {
                Text("One keystroke away.")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Press ⌘ ; to hide Resolve. Press it again to bring it back from anywhere.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            HStack(spacing: 12) {
                OnboardingPulseKeycap(keys: "⌘ ;")

                Text("try it now")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var hotkeyResolvedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            VStack(alignment: .leading, spacing: 8) {
                Text("That's the toggle.")
                    .font(.system(size: 20, weight: .semibold))

                // The keycap is rendered inline so the user can recognize
                // ⌘ ; as a command, not just a glyph buried in copy.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    OnboardingPulseKeycap(keys: "⌘ ;", pulses: false)

                    Text("brings Resolve up from anywhere, and tucks it away the moment you're done.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer(minLength: 0)
                OnboardingContinueButton(title: "Continue", keyHint: "⌘ ↵") {
                    advance(to: .signIn)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var signInContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            VStack(alignment: .leading, spacing: 6) {
                Text("Sign in to continue.")
                    .font(.system(size: 20, weight: .semibold))

                Text("Resolve uses a secure browser flow. We'll bring you right back here when you're done.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            OnboardingPrimaryButton(title: "Sign in", keyHint: "⌘ ↵") {
                authManager.startSignIn()
            }
            .keyboardShortcut(.return, modifiers: .command)

            HStack(spacing: 6) {
                Text("New here?")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.tertiary)

                ResolveInlineLinkButton("Create an account") {
                    authManager.startSignIn()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var signingInContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            VStack(spacing: 10) {
                OnboardingBreathingDot(diameter: 22)

                Text("Finishing up in your browser…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Come back here once you've signed in.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome, \(welcomeFirstName).")
                    .font(.system(size: 22, weight: .semibold))

                Text("A quick look at how Resolve works, then you're in.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer(minLength: 0)
                OnboardingContinueButton(title: "Show me", keyHint: "⌘ ↵") {
                    advance(to: .concept)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var conceptContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            Text("How Resolve works.")
                .font(.system(size: 20, weight: .semibold))

            VStack(alignment: .leading, spacing: 12) {
                ConceptBeatRow(
                    number: "1",
                    title: "Ask anything.",
                    detail: "Type a question. Strategic, technical, or open-ended.",
                    revealed: conceptRevealCount >= 1
                )
                ConceptBeatRow(
                    number: "2",
                    title: "Multiple AIs answer independently.",
                    detail: "Each model writes its own response. No blending, no rewriting.",
                    revealed: conceptRevealCount >= 2
                )
                ConceptBeatRow(
                    number: "3",
                    title: "The arbiter resolves disagreement.",
                    detail: "When models diverge, the arbiter shows you exactly where and why.",
                    revealed: conceptRevealCount >= 3
                )
            }

            HStack(spacing: 12) {
                ResolveInlineLinkButton("Skip") {
                    onComplete(false)
                }

                Spacer(minLength: 0)

                // ⌘N is the global "new chat" hotkey owned by KeyboardShortcuts,
                // so it can't be bound here as a SwiftUI shortcut directly —
                // the global handler intercepts the chord first. Instead we
                // listen for `diveInNotification` (posted by that handler) at
                // the view level and fire `onComplete(true)` when the user
                // hits ⌘N on the concept step. Clicking the button does the
                // same thing.
                OnboardingPrimaryButton(title: "Try Resolve", keyHint: "⌘ N") {
                    onComplete(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            startConceptReveal()
        }
    }

    /// Reserves invisible space for the persistent R overlay (so the wordmark
    /// sits next to where the R is positioned) and renders the "Resolve"
    /// wordmark. The R itself is drawn at the panel level so it can morph
    /// across steps without being torn down and recreated each time.
    private var headerRow: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: headerLogoSize, height: headerLogoSize)

            Text("Resolve")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Logic

    private var welcomeFirstName: String {
        if case .signedIn(let user) = authManager.state {
            let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = trimmed.split(separator: " ").first {
                return String(first)
            }
            if !trimmed.isEmpty { return trimmed }
        }
        return "there"
    }

    private func applyPanelSize(animated: Bool) {
        // `.center` anchor: the panel grows in all four directions from its
        // current center instead of pinning the top edge. Combined with the
        // persistent R sitting at the panel center during arrival, the
        // unfurl reads as a single object expanding outward.
        CommandPanelController.shared.setSize(
            width: panelSize.width,
            height: panelSize.height,
            animated: animated,
            duration: morphDuration,
            anchor: .center
        )
    }

    /// Two-phase entrance:
    ///   1. After a short pause on the lone R, advance to `.unfurled`. This
    ///      kicks off the panel-grow morph; the R rides the panel center.
    ///   2. Once the panel has finished growing, advance to either `.hotkey`
    ///      (first-time users — teach them ⌘ ;) or `.signIn` directly
    ///      (returning users who have already finished the tour).
    private func startArrivalSequenceIfNeeded() {
        guard !arrivalDidStart else { return }
        arrivalDidStart = true

        let initialPause: Double = settings.reducedMotion ? 0.05 : 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + initialPause) {
            advance(to: .unfurled)

            let unfurlPause: Double = settings.reducedMotion
                ? 0.0
                : morphDuration + 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + unfurlPause) {
                guard step == .unfurled else { return }
                // Returning users (have already learned ⌘ ;) skip straight
                // to the sign-in card. First-time users get the teaching.
                if settings.hasCompletedOnboarding {
                    advance(to: .signIn)
                } else {
                    advance(to: .hotkey)
                }
            }
        }
    }

    /// Advance to the next step. If the user is already signed in (returning
    /// user who somehow lands in onboarding again), skip the auth steps.
    private func advance(to next: Step) {
        var target = next
        if (target == .signIn || target == .signingIn), case .signedIn = authManager.state {
            target = .welcome
        }
        let animation = settings.animation(.easeInOut(duration: morphDuration))
        withAnimation(animation) {
            step = target
        }
    }

    private func registerToggleListener() {
        togglePaletteToken = NotificationCenter.default.addObserver(
            forName: togglePaletteUsedNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleTogglePalettePress()
        }
    }

    /// ⌘N is the "Try Resolve" / new-chat shortcut at the global level. The
    /// `KeyboardShortcuts` library posts `diveInNotification` whenever the
    /// chord fires; we listen here so pressing ⌘N on the concept step is
    /// equivalent to clicking "Try Resolve" — it completes onboarding and
    /// drops the user straight into a fresh chat.
    private func registerDiveInListener() {
        diveInToken = NotificationCenter.default.addObserver(
            forName: diveInNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleDiveInPress()
        }
    }

    private func handleDiveInPress() {
        // ⌘N is the global "open a new chat" hotkey. After the user is
        // signed in, pressing it should be equivalent to clicking "Try
        // Resolve" on the concept step — bypass the rest of onboarding
        // and drop them straight into a fresh chat. Pressing it during
        // sign-in / hotkey-teaching beats is intentionally a no-op.
        switch step {
        case .welcome, .concept:
            onComplete(true)
        default:
            break
        }
    }

    /// Drives the hotkey teaching beat. The first press hides the panel; the
    /// second brings it back. We morph content on the second press so the user
    /// sees the panel reappear *and* deliver the success message in one beat.
    private func handleTogglePalettePress() {
        switch step {
        case .hotkey:
            step = .hotkeyHidden
        case .hotkeyHidden:
            advance(to: .hotkeyResolved)
        default:
            break
        }
    }

    private func handleAuthStateChange(_ newValue: AuthManager.AuthState) {
        switch newValue {
        case .signingIn:
            if step == .signIn {
                advance(to: .signingIn)
            }
        case .signedIn:
            if step == .signIn || step == .signingIn {
                if settings.hasCompletedOnboarding {
                    // Returning user: they've already seen the welcome and
                    // concept beats. Bypass them and finish onboarding so
                    // RootPanelView routes straight to home.
                    onComplete(false)
                } else {
                    advance(to: .welcome)
                }
            }
        case .signedOut:
            if step == .signingIn {
                advance(to: .signIn)
            }
        }
    }

    private func startConceptReveal() {
        guard conceptRevealCount == 0 else { return }
        if settings.reducedMotion {
            conceptRevealCount = 3
            return
        }
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.42) {
                withAnimation(.easeOut(duration: 0.32)) {
                    conceptRevealCount = i
                }
            }
        }
    }
}

// MARK: - Sub-components

private struct ConceptBeatRow: View {
    let number: String
    let title: String
    let detail: String
    let revealed: Bool

    @ObservedObject private var settings = UserSettingsStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(7), style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(7), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .opacity(revealed ? 1.0 : 0.0)
        .offset(y: revealed ? 0 : 6)
    }
}

/// Shared keycap visual used by every onboarding CTA. Rendering it through
/// a single helper keeps the look consistent and lets both button styles
/// surface their keyboard shortcut to the user — the goal is that a user
/// never *has* to reach for the trackpad to get through onboarding.
private struct OnboardingKeycap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct OnboardingPrimaryButton: View {
    let title: String
    let keyHint: String?
    let action: () -> Void

    @State private var isHovering = false

    init(title: String, keyHint: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.keyHint = keyHint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)

                Spacer(minLength: 0)

                if let keyHint {
                    OnboardingKeycap(keys: keyHint)
                }
            }
        }
        .buttonStyle(ResolvePrimaryButtonStyle(isHovering: isHovering))
        .onHover { isHovering = $0 }
        // Each call site binds its own keyboard shortcut so the keycap
        // accurately reflects what activates the button (cmd+return for
        // sign-in, ⌘N for "Try Resolve" via the global new-chat hotkey).
    }
}

/// Lighter-weight CTA used on transitional beats (hotkey-resolved, welcome).
/// Distinct from `OnboardingPrimaryButton` so the visual hierarchy stays clear:
/// primary buttons fill width and look "decisive"; continue buttons are a soft
/// pill in the bottom-right. Both surface their keyboard shortcut via the
/// shared `OnboardingKeycap` so the whole flow is keyboard-navigable.
private struct OnboardingContinueButton: View {
    let title: String
    let keyHint: String?
    let action: () -> Void

    @ObservedObject private var settings = UserSettingsStore.shared
    @State private var isHovering = false

    init(title: String, keyHint: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.keyHint = keyHint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if let keyHint {
                    OnboardingKeycap(keys: keyHint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.14 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                    .strokeBorder(Color.white.opacity(isHovering ? 0.18 : 0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        // Cmd+return matches the primary-button shortcut (Sign in), so the
        // user has one consistent "advance" chord across the whole flow.
        .keyboardShortcut(.return, modifiers: .command)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.6)
        OnboardingFlowView(onComplete: { _ in })
            .environmentObject(AuthManager.shared)
    }
    .frame(width: 900, height: 600)
    .preferredColorScheme(.dark)
}
