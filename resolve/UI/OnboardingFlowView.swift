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
        case questionPicker   // pick a fun pre-baked question
        case demoState1       // canned chat: 3-2 disagreement
        case demoState2       // canned chat: 4-1 after first ⌘⇧R
        case demoState3       // canned chat: 5-0 consensus
        case cheatSheet       // keyboard shortcuts grid + Continue
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
    @State private var resolveRoundToken: NSObjectProtocol?
    @State private var conceptRevealCount: Int = 0
    @State private var arrivalDidStart: Bool = false

    /// The set of pre-baked questions surfaced in `.questionPicker`. Picked
    /// once per onboarding run from `OnboardingDemoData.allQuestions` so the
    /// picker feels fresh on every replay.
    @State private var availableQuestions: [OnboardingDemoQuestion] = OnboardingDemoData.randomSelection(count: 5)
    /// Index into `availableQuestions` once the user has chosen one. Drives
    /// which question's pre-baked states get rendered in the demo chat, and
    /// which row in the picker carries the matchedGeometryEffect into the
    /// `lastSentText` panel.
    @State private var selectedQuestionIndex: Int? = nil
    /// True for ~3 seconds after the user fires a resolve round, so the
    /// pulse goes quiet for a beat before resuming. Reset on entry to a
    /// fresh demo state.
    @State private var resolvePulseSuppressed: Bool = false
    /// True while the canned 1-second "advocates are debating" beat is
    /// playing, between a resolve press and the next state actually
    /// landing. Makes the demo feel like a real round-trip.
    @State private var demoIsResolving: Bool = false
    /// Which advocate card the user has clicked open in the drawer, if any.
    /// `nil` means the drawer is closed and the panel renders at base width.
    @State private var selectedDemoAdvocate: AdvocateProvider? = nil
    /// Vertical offset applied to the cheat-sheet content during the
    /// cheat sheet → home morph. As the panel's top edge moves up to make
    /// room for the home view's welcome heading + Get started + links,
    /// the cheat sheet's content shifts DOWN by the same amount via this
    /// offset — net result: the shortcuts grid stays at exactly the same
    /// screen position throughout the morph instead of riding the panel up.
    @State private var cheatSheetTopOffset: CGFloat = 0
    /// Flips true at the start of the cheat sheet → home morph. Fades out
    /// the cheat sheet's logo + intro + Continue button so when the home
    /// view mounts (with its different header content), the only thing
    /// visible during the swap is the shortcuts grid — which lines up
    /// pixel-for-pixel with the home view's shortcuts grid.
    @State private var cheatSheetIsTransitioning: Bool = false

    /// Shared namespace for the question text's morph from picker → demo
    /// chat `lastSentText`. Each question's row uses `id: question.id`, and
    /// the demo chat's question Text uses the same id once `selectedQuestion`
    /// is set, so SwiftUI animates the text between the two layouts.
    @Namespace private var questionMorph

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
        case .questionPicker:
            return CGSize(width: settings.scaled(540), height: settings.scaled(390))
        case .demoState1, .demoState2, .demoState3:
            // Drawer adds 260pt to the right when an advocate card is open.
            let demoBaseWidth: CGFloat = 760
            let demoDrawerWidth: CGFloat = 260
            let totalWidth = demoBaseWidth + (selectedDemoAdvocate != nil ? demoDrawerWidth : 0)
            return CGSize(width: settings.scaled(totalWidth), height: settings.scaled(490))
        case .cheatSheet:
            return CGSize(width: settings.scaled(520), height: settings.scaled(310))
        }
    }

    /// Anchor used for panel size morphs. Most steps grow centered; the
    /// final cheat sheet → home transition wants the bottom edge anchored
    /// so the panel grows upward into the home view's territory.
    private var panelAnchor: CommandPanelFrameAnchor {
        // Continue from cheat sheet calls onComplete which unmounts this
        // view. The home view's onAppear fires its own setSize. Anchoring
        // *that* setSize to .bottomCenter is what makes the panel grow up
        // — handled in AuthenticatedView. Here all of onboarding uses the
        // central, "unfurl outward" anchor.
        .center
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
            registerResolveRoundListener()
            startArrivalSequenceIfNeeded()
        }
        .onChange(of: step) { _, _ in
            applyPanelSize(animated: !settings.reducedMotion)
        }
        .onChange(of: selectedDemoAdvocate) { _, _ in
            // Drawer width snaps without animation — same feel as the
            // real chat panel's drawer toggle.
            applyPanelSize(animated: false)
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
            if let token = resolveRoundToken {
                NotificationCenter.default.removeObserver(token)
                resolveRoundToken = nil
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
        case .questionPicker:
            questionPickerContent
                .transition(.opacity)
        case .demoState1, .demoState2, .demoState3:
            demoChatContent
                .transition(.opacity)
        case .cheatSheet:
            cheatSheetContent
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
                ResolveInlineLinkButton("Skip tutorial") {
                    onComplete(false)
                }

                Spacer(minLength: 0)

                // Continue advances into the canned demo (question picker
                // → demo chat → cheat sheet → home). ⌘N still works as a
                // hard skip into a real chat (handled by the global
                // diveInNotification listener), but the natural advance
                // chord is cmd+return.
                OnboardingPrimaryButton(title: "Continue", keyHint: "⌘ ↵") {
                    advance(to: .questionPicker)
                }
                .keyboardShortcut(.return, modifiers: .command)
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

    /// "Skip tutorial" link rendered top-right on the demo beats. Calls
    /// `onComplete(false)` so the user lands on the home screen, exactly
    /// like the Skip link on the concept page.
    private var skipTutorialLink: some View {
        ResolveInlineLinkButton("Skip tutorial") {
            onComplete(false)
        }
    }

    /// Header row variant that sits the wordmark on the left and the
    /// "Skip tutorial" link on the far right. Used on every demo beat.
    private var headerRowWithSkip: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: headerLogoSize, height: headerLogoSize)

            Text("Resolve")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            skipTutorialLink
        }
    }

    // MARK: - Question picker

    private var selectedQuestion: OnboardingDemoQuestion? {
        guard let idx = selectedQuestionIndex,
              availableQuestions.indices.contains(idx) else { return nil }
        return availableQuestions[idx]
    }

    private var questionPickerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRowWithSkip

            VStack(alignment: .leading, spacing: 4) {
                Text("Pick a question.")
                    .font(.system(size: 20, weight: .semibold))

                Text("Try a real Resolve round on something fun. Press the keycap or click a row.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(Array(availableQuestions.enumerated()), id: \.element.id) { idx, question in
                    OnboardingQuestionRow(
                        question: question,
                        keycap: "⌘ \(idx + 1)",
                        morphNamespace: questionMorph
                    ) {
                        pickQuestion(at: idx)
                    }
                    .keyboardShortcut(Self.numberShortcut(for: idx), modifiers: .command)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func pickQuestion(at index: Int) {
        guard step == .questionPicker else { return }
        guard availableQuestions.indices.contains(index) else { return }
        selectedQuestionIndex = index
        // resolvePulseSuppressed is reset to false (default); state 1
        // begins with the resolve button pulsing immediately.
        resolvePulseSuppressed = false
        demoIsResolving = false
        selectedDemoAdvocate = nil
        advance(to: .demoState1)
    }

    /// Static lookup for ⌘1–⌘9 shortcuts. Building `KeyEquivalent` from
    /// an interpolated string isn't reliable across Swift versions; using
    /// character literals here keeps the compiler happy and gives us a
    /// hard cap (any picker beyond 9 entries would fail loudly).
    private static let numberKeys: [KeyEquivalent] = [
        KeyEquivalent("1"), KeyEquivalent("2"), KeyEquivalent("3"),
        KeyEquivalent("4"), KeyEquivalent("5"), KeyEquivalent("6"),
        KeyEquivalent("7"), KeyEquivalent("8"), KeyEquivalent("9")
    ]

    private static func numberShortcut(for index: Int) -> KeyEquivalent {
        guard numberKeys.indices.contains(index) else { return KeyEquivalent("0") }
        return numberKeys[index]
    }

    // MARK: - Demo chat

    /// Live state being rendered in the demo chat (advocates, arbiter
    /// summary, classifier groups). Returns nil on non-demo steps.
    private var currentDemoState: OnboardingDemoState? {
        guard let question = selectedQuestion else { return nil }
        let stateIndex: Int
        switch step {
        case .demoState1: stateIndex = 0
        case .demoState2: stateIndex = 1
        case .demoState3: stateIndex = 2
        default: return nil
        }
        guard question.states.indices.contains(stateIndex) else { return nil }
        return question.states[stateIndex]
    }

    private var demoRoundNumber: Int {
        switch step {
        case .demoState1: return 1
        case .demoState2: return 2
        case .demoState3: return 3
        default: return 1
        }
    }

    private var demoCanResolve: Bool {
        // Resolve is disabled at consensus AND while the 1s loading beat
        // is playing — preventing back-to-back ⌘⇧R presses from racing.
        (step == .demoState1 || step == .demoState2) && !demoIsResolving
    }

    private var demoResolvePulseActive: Bool {
        demoCanResolve && !resolvePulseSuppressed
    }

    private var demoResolveCaption: String {
        if demoIsResolving {
            return "Advocates are debating…"
        }
        switch step {
        case .demoState1, .demoState2:
            return "Models disagree — press ⌘⇧R to ask the arbiter to resolve."
        case .demoState3:
            return "Consensus reached. Press ⌘ ↵ to continue."
        default:
            return ""
        }
    }

    @ViewBuilder
    private var demoChatContent: some View {
        if let question = selectedQuestion, let state = currentDemoState {
            VStack(alignment: .leading, spacing: 12) {
                headerRowWithSkip

                HStack(alignment: .top, spacing: 12) {
                    demoLeftColumn(question: question, state: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    demoRightColumn(state: state)
                        .frame(width: settings.scaled(230))

                    if let selected = selectedDemoAdvocate,
                       let advocate = state.advocates.first(where: { $0.provider == selected }) {
                        demoDrawer(for: advocate)
                            .frame(width: settings.scaled(260))
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    Text(demoResolveCaption)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(demoCanResolve ? settings.resolvedAccentColor.opacity(0.85) : Color.secondary)
                        .opacity(demoResolveCaption.isEmpty ? 0 : 1)

                    Spacer(minLength: 0)

                    // Continue is only offered once consensus is reached.
                    // States 1 + 2 expect ⌘⇧R; the caption above tells the
                    // user that. State 3 swaps in this button so users who
                    // prefer clicks have a visible target.
                    if step == .demoState3 {
                        OnboardingContinueButton(title: "Continue", keyHint: "⌘ ↵") {
                            advance(to: .cheatSheet)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            Color.clear
        }
    }

    private func demoDrawer(for advocate: OnboardingDemoAdvocate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(advocate.provider.displayName)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button {
                    selectedDemoAdvocate = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(7), style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(7), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
            }

            Text("Detailed reasoning")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                Text(advocate.detailedReasoning)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func demoLeftColumn(question: OnboardingDemoQuestion, state: OnboardingDemoState) -> some View {
        VStack(spacing: 12) {
            lastSentPanel(question: question)

            Divider()
                .overlay(Color.white.opacity(0.10))

            HStack(spacing: 8) {
                Text("Arbiter's Summary")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text("\(demoRoundNumber)/3 rounds")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                OnboardingPulsingResolveButton(
                    isPulsing: demoResolvePulseActive,
                    isEnabled: demoCanResolve,
                    cornerRadius: settings.cornerRadius(9),
                    accentColor: settings.resolvedAccentColor
                ) {
                    triggerDemoResolve()
                }
            }

            // While the 1-second loading beat plays we swap the arbiter
            // summary out for a spinner — same pattern the real chat uses
            // between resolve rounds. Makes the demo feel like a real
            // round-trip even though the next state is pre-baked.
            if demoIsResolving {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)

                    Text("Advocates are debating…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(arbiterAttributedString(state.arbiterSummary))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func demoRightColumn(state: OnboardingDemoState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Text("General Question")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.advocates, id: \.provider) { advocate in
                        Button {
                            toggleDemoAdvocate(advocate.provider)
                        } label: {
                            OnboardingDemoAdvocateCard(
                                advocate: advocate,
                                stanceColor: stanceColor(for: advocate.provider, in: state.classifierGroups),
                                isSelected: selectedDemoAdvocate == advocate.provider,
                                isLoading: demoIsResolving,
                                cornerRadius: settings.cornerRadius(10),
                                selectionTint: settings.resolvedAccentColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func toggleDemoAdvocate(_ provider: AdvocateProvider) {
        if selectedDemoAdvocate == provider {
            selectedDemoAdvocate = nil
        } else {
            selectedDemoAdvocate = provider
        }
    }

    private func lastSentPanel(question: OnboardingDemoQuestion) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)

            Text("\(question.emoji)  \(question.title)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .matchedGeometryEffect(id: question.id, in: questionMorph)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    /// Maps an advocate to its stance color based on the current state's
    /// classifier groups. First group gets the first palette color,
    /// second gets the second, etc. — same convention as the real chat.
    private func stanceColor(for provider: AdvocateProvider, in groups: [OnboardingDemoStanceGroup]) -> Color? {
        let key = provider.backendKey
        let palette = settings.stancePalette.colors
        for (idx, group) in groups.enumerated() {
            if group.members.contains(key) {
                return palette[idx % palette.count]
            }
        }
        return nil
    }

    /// Tiny markdown-ish parser for the canned arbiter summaries — supports
    /// **bold** segments only (everything else is plain). We don't reuse the
    /// real chat's parser because that pulls in the whole resolve text
    /// pipeline; for ~5 hard-coded strings, this is enough.
    private func arbiterAttributedString(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]
        var bold = false
        while let range = remaining.range(of: "**") {
            let chunk = remaining[remaining.startIndex..<range.lowerBound]
            var segment = AttributedString(String(chunk))
            if bold {
                segment.font = .system(size: 14, weight: .semibold)
            }
            result += segment
            remaining = remaining[range.upperBound...]
            bold.toggle()
        }
        var tail = AttributedString(String(remaining))
        if bold {
            tail.font = .system(size: 14, weight: .semibold)
        }
        result += tail
        return result
    }

    private func triggerDemoResolve() {
        guard demoCanResolve else { return }
        let nextStep: Step
        switch step {
        case .demoState1: nextStep = .demoState2
        case .demoState2: nextStep = .demoState3
        default: return
        }

        // Pretend we're hitting an API: spinner for 1s, then advance to
        // the next pre-baked state. Keeps the demo feeling alive instead
        // of snapping instantly between states.
        demoIsResolving = true
        resolvePulseSuppressed = true

        let resolveDelay: Double = settings.reducedMotion ? 0.0 : 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + resolveDelay) {
            demoIsResolving = false
            advance(to: nextStep)

            // Pulse stays quiet for another 2s after the new state lands
            // (3s total from button press), so the user gets a beat to
            // read the result before the button starts pulsing again.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                resolvePulseSuppressed = false
            }
        }
    }

    // MARK: - Cheat sheet

    private var cheatSheetContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRowWithSkip
                .opacity(cheatSheetIsTransitioning ? 0 : 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your keyboard cheat sheet.")
                    .font(.system(size: 18, weight: .semibold))

                Text("Resolve is fastest from the keyboard. Here's everything you'll use.")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .opacity(cheatSheetIsTransitioning ? 0 : 1)

            // Shortcut rows stay visible through the morph — they're the
            // anchor that the home view's shortcuts will land on.
            // Sourced from the same catalog as the home list (see
            // `hotkeys/KeyboardShortcuts.swift`). The cheat sheet always
            // runs on the primary panel, so the context is fixed.
            VStack(spacing: 6) {
                ForEach(KeyboardShortcutCatalog.shortcuts(
                    for: .onboardingCheatSheet,
                    context: KeyboardShortcutContext(isPrimaryPanel: true, canCloseInstance: false)
                )) { entry in
                    OnboardingShortcutRow(label: entry.label, keys: entry.keys)
                }
            }

            HStack {
                Spacer(minLength: 0)
                OnboardingContinueButton(title: "Continue", keyHint: "⌘ ↵") {
                    transitionFromCheatSheetToHome()
                }
            }
            .opacity(cheatSheetIsTransitioning ? 0 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // `.offset` translates the rendered view without affecting layout.
        // As the panel's top edge moves up during the morph, this offset
        // pushes the cheat-sheet content the same amount DOWN, so the
        // shortcuts grid (and everything else) stays still on screen.
        .offset(y: cheatSheetTopOffset)
    }

    private func transitionFromCheatSheetToHome() {
        // Cheat sheet → home morph anchored on the keyboard-shortcuts grid.
        //
        // Two synchronized animations make this work:
        //
        //   1. The AppKit panel grows asymmetrically — top edge up to make
        //      room for the home view's header + Get started + links area;
        //      bottom edge down to match the home view's natural padding.
        //      Anchor pegs `cheatSheetShortcutsY` (in old layout) to
        //      `homeShortcutsY` (in new layout) so a fixed point in the
        //      panel's content stays at the same screen y.
        //
        //   2. SwiftUI side-effect: the cheat sheet's content gets pushed
        //      DOWN by exactly the amount the panel top moves UP. Result:
        //      every visible element of the cheat sheet stays at the same
        //      screen y throughout the morph instead of riding the panel
        //      upward. The header / intro / Continue button fade out, and
        //      the shortcut rows stay perfectly still — landing exactly on
        //      top of the home view's shortcut rows when AuthenticatedView
        //      mounts after the morph completes.
        //
        // The two Y values are measured (approximately) from each panel's
        // top edge to the top of the shortcut rows. They scale with the
        // panel-size setting so the morph works at every panel size.
        let homeSize = CGSize(width: settings.scaled(520), height: settings.scaled(410))
        let cheatSheetShortcutsY: CGFloat = settings.scaled(120)
        let homeShortcutsY: CGFloat = settings.scaled(178)
        let topOffsetDelta: CGFloat = homeShortcutsY - cheatSheetShortcutsY

        // Kick off the AppKit panel resize.
        CommandPanelController.shared.setSize(
            width: homeSize.width,
            height: homeSize.height,
            animated: !settings.reducedMotion,
            duration: morphDuration,
            anchor: .anchorTopFromContent(currentY: cheatSheetShortcutsY, newY: homeShortcutsY)
        )

        // Drive the SwiftUI side at the same duration + curve as the
        // panel resize, so the offset compensation stays in lockstep
        // with the panel top moving up.
        if settings.reducedMotion {
            cheatSheetTopOffset = topOffsetDelta
            cheatSheetIsTransitioning = true
        } else {
            withAnimation(.easeInOut(duration: morphDuration)) {
                cheatSheetTopOffset = topOffsetDelta
                cheatSheetIsTransitioning = true
            }
        }

        // After the morph completes, swap to the home view. The panel is
        // already at home dimensions, so AuthenticatedView's onAppear
        // setSize is a no-op — the view just mounts in place.
        let delay = settings.reducedMotion ? 0.0 : morphDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onComplete(false)
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
        // ⌘N is the global "open a new chat" hotkey. Once the user is
        // signed in (welcome onward), pressing it bypasses the rest of
        // onboarding and drops them into a fresh chat. Pre-sign-in
        // beats and the demo-internal beats explicitly do nothing — the
        // demo has its own progression chord (⌘⇧R / ⌘ ↵).
        switch step {
        case .welcome, .concept, .cheatSheet:
            onComplete(true)
        default:
            break
        }
    }

    /// ⌘⇧R is the global "Resolve" hotkey. We listen for it in the demo
    /// states so pressing the chord (or clicking the button — both end
    /// up here via the same path) advances the canned conversation.
    private func registerResolveRoundListener() {
        resolveRoundToken = NotificationCenter.default.addObserver(
            forName: resolveRoundNotification,
            object: nil,
            queue: .main
        ) { _ in
            triggerDemoResolve()
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

/// One row in the question picker. Keycap on the left, emoji + question
/// title on the right. The title carries the matchedGeometryEffect so it
/// can morph into the demo chat's `lastSentText` when picked.
private struct OnboardingQuestionRow: View {
    let question: OnboardingDemoQuestion
    let keycap: String
    let morphNamespace: Namespace.ID
    let action: () -> Void

    @ObservedObject private var settings = UserSettingsStore.shared
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                OnboardingKeycap(keys: keycap)

                Text(question.emoji)
                    .font(.system(size: 16))

                Text(question.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .matchedGeometryEffect(id: question.id, in: morphNamespace)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.10 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                    .strokeBorder(Color.white.opacity(isHovering ? 0.16 : 0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Resolve button as it appears in the demo. Pulses (scale + accent glow)
/// when `isPulsing` is true. The keycap inside matches the global ⌘⇧R
/// hotkey that the user can press to fire it. Disabled (no pulse, dimmed)
/// once consensus is reached.
private struct OnboardingPulsingResolveButton: View {
    let isPulsing: Bool
    let isEnabled: Bool
    let cornerRadius: CGFloat
    let accentColor: Color
    let action: () -> Void

    @ObservedObject private var settings = UserSettingsStore.shared
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseGlow: Double = 0.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Resolve")
                    .font(.system(size: 12, weight: .semibold))

                OnboardingKeycap(keys: "⌘ ⇧ R")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accentColor.opacity(isEnabled ? 0.20 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(accentColor.opacity(isEnabled ? (0.40 + pulseGlow) : 0.12), lineWidth: 1)
            )
            .shadow(color: accentColor.opacity(pulseGlow), radius: CGFloat(pulseGlow) * 24)
        }
        .buttonStyle(.plain)
        .scaleEffect(pulseScale)
        .opacity(isEnabled ? 1.0 : 0.55)
        .disabled(!isEnabled)
        // ⌘⇧R fires the action via the global resolveRoundNotification
        // listener in OnboardingFlowView; no SwiftUI shortcut here would
        // win against the KeyboardShortcuts library anyway.
        .onAppear {
            applyPulse(active: isPulsing)
        }
        .onChange(of: isPulsing) { _, newValue in
            applyPulse(active: newValue)
        }
    }

    private func applyPulse(active: Bool) {
        if active && !settings.reducedMotion {
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
                pulseGlow = 0.45
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                pulseScale = 1.0
                pulseGlow = 0.0
            }
        }
    }
}

/// Compact advocate "thesis card" used in the demo chat. Mirrors the visual
/// of `AdvocateThesisCardView` from the real chat — provider name + summary
/// + a colored stance capsule when the classifier groups have placed this
/// advocate in a stance. Clickable: tapping toggles the detail drawer.
private struct OnboardingDemoAdvocateCard: View {
    let advocate: OnboardingDemoAdvocate
    let stanceColor: Color?
    let isSelected: Bool
    let isLoading: Bool
    let cornerRadius: CGFloat
    let selectionTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(advocate.provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if let stanceColor {
                    Capsule(style: .continuous)
                        .fill(stanceColor.opacity(0.85))
                        .frame(width: 60, height: 3)
                }
            }

            Text(advocate.summary)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? selectionTint.opacity(0.55) : Color.white.opacity(0.10),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .trailing) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .padding(.trailing, 10)
            }
        }
        .opacity(isLoading ? 0.65 : 1.0)
    }
}

/// One row of the cheat-sheet keyboard shortcuts grid. Visual matches
/// `AuthenticatedView`'s ShortcutRow so the cheat-sheet beat is
/// pixel-similar to the home screen's shortcuts section it eventually
/// becomes.
private struct OnboardingShortcutRow: View {
    let label: String
    let keys: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            OnboardingKeycap(keys: keys)
        }
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
