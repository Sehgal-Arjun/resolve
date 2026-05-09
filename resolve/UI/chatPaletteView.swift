import SwiftUI
import AppKit
import UniformTypeIdentifiers

fileprivate struct RoundSnapshot {
    let runId: UUID
    let arbiterSummaryText: String
    let advocateResults: [AdvocateResult]
    let classifierGroups: [ClassifierGroup]
    let mcqDisagreement: Bool?
    let submittedProblemType: ProblemType
    let lastPromptTypeForBackend: String
}

struct ChatPaletteView: View {
    let initialConversationId: UUID?
    let onBack: (() -> Void)?

    enum Phase {
        case composing
        case loading
        case responded
    }

    init(initialConversationId: UUID? = nil, onBack: (() -> Void)? = nil) {
        self.initialConversationId = initialConversationId
        self.onBack = onBack
    }

    @State private var text = ""
    @State private var phase: Phase = .composing
    @State private var isBackButtonHovering = false
    @State private var isSendButtonHovering = false
    /// Drives the small floating chip at the top of the chat panel for
    /// "Summary copied", "Exported to Downloads", etc. Nil hides the
    /// toast; a non-nil value renders it for ~1.3s and then clears.
    @State private var toast: ChatToast? = nil
    @State private var toastDismissTask: Task<Void, Never>? = nil

    struct ChatToast: Equatable {
        let message: String
        let iconName: String
    }
    @State private var arbiterSummaryText = ""
    @State private var isArbiterThinking = false
    @State private var roundIndex: Int = 0
    @State private var isResolveRoundInFlight = false
    @State private var lastSentText = ""
    @State private var problemType: ProblemType = .generalQuestion
    @State private var submittedProblemType: ProblemType = .generalQuestion
    @State private var advocateResults: [AdvocateResult] = []
    @State private var selectedAdvocateId: String?
    @State private var currentConversationId: UUID?
    @State private var lastUserMessageId: UUID?
    @State private var lastPromptTypeForBackend: String = "general"
    @State private var classifierGroups: [ClassifierGroup] = []
    @State private var mcqDisagreement: Bool? = nil
    @State private var showHistoricalEmptyState = false
    @State private var allowPlaceholderAdvocates = true
    @State private var lastResolveCorrelationId: String?
    @State private var roundSnapshots: [RoundSnapshot] = []
    @State private var viewedRoundIndex: Int = 0

    @ObservedObject private var settings = UserSettingsStore.shared
    @FocusState private var focused: Bool
    @Environment(\.resolvePanelController) private var panelController

    private let api = BackendAPIClient()

    private var baseHeight: CGFloat { settings.scaled(140) }
    private var expandedHeight: CGFloat { settings.scaled(460) }
    private var baseWidth: CGFloat { settings.scaled(620) }
    private var expandedWidth: CGFloat { settings.scaled(760) }
    private var drawerWidth: CGFloat { settings.scaled(260) }
    private var singleSelectAdvocateWidth: CGFloat { settings.scaled(150) }
    private var multiSelectAdvocateWidth: CGFloat { settings.scaled(170) }
    private var generalQuestionAdvocateWidth: CGFloat { settings.scaled(230) }
    private let advocateTopPadding: CGFloat = 44

    private var maxRounds: Int {
        settings.maxResolveRounds
    }

    private var canSend: Bool {
        phase != .loading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDrawerOpen: Bool {
        selectedAdvocateId != nil
    }

    private var currentAdvocates: [AdvocateResult] {
        if !advocateResults.isEmpty {
            return advocateResults
        }
        guard allowPlaceholderAdvocates else { return [] }
        return AdvocateClient.placeholderResults.filter { settings.enabledAdvocates.contains($0.provider) }
    }

    private var currentPanelWidth: CGFloat {
        let base = phase == .composing ? baseWidth : expandedWidth
        return isDrawerOpen && phase != .composing ? base + drawerWidth : base
    }

    private var providerAccentColors: [AdvocateProvider: Color] {
        [
            .openAI: .blue,
            .anthropic: .purple,
            .gemini: .orange,
            .deepSeek: .teal,
            .mistral: .pink
        ]
    }

    private var hasDisagreement: Bool {
        switch submittedProblemType {
        case .generalQuestion:
            // only enable resolve when classifier says multiple stances
            return classifierGroups.count > 1

        case .multipleChoiceSingle, .multipleChoiceMulti:
            // trust backend’s local MCQ disagreement if present; otherwise fall back
            if let mcqDisagreement { return mcqDisagreement }
            return classifierGroups.count > 1
        }
    }

    private var shouldShowStanceColors: Bool {
        settings.showStanceColors &&
        phase == .responded &&
        !isArbiterThinking &&
        !isResolveRoundInFlight &&
        !classifierGroups.isEmpty
    }

    private var resolvesUsed: Int {
        min(roundIndex, maxRounds)
    }

    private var resolvesRemaining: Int {
        max(0, maxRounds - resolvesUsed)
    }

    private var resolvesRemainingText: String {
        "\(resolvesRemaining)/\(maxRounds) resolves remaining"
    }

    private var canResolve: Bool {
        currentConversationId != nil &&
        lastUserMessageId != nil &&
        resolvesUsed < maxRounds &&
        !isResolveRoundInFlight &&
        !isArbiterThinking &&
        phase == .responded &&
        hasDisagreement &&
        isViewingLatestRound
    }

    private var isViewingLatestRound: Bool {
        roundSnapshots.isEmpty || viewedRoundIndex == roundSnapshots.count - 1
    }

    private var canGoBackRound: Bool {
        !isResolveRoundInFlight && !isArbiterThinking && viewedRoundIndex > 0
    }

    private var canGoForwardRound: Bool {
        !isResolveRoundInFlight && !isArbiterThinking && viewedRoundIndex < roundSnapshots.count - 1
    }

    private var stancePalette: [Color] {
        settings.stancePalette.colors
    }

    private func stanceColor(for provider: AdvocateProvider) -> Color? {
        let key: String
        switch provider {
        case .openAI: key = "openai"
        case .anthropic: key = "anthropic"
        case .gemini: key = "gemini"
        case .deepSeek: key = "deepseek"
        case .mistral: key = "mistral"
        }

        let palette = stancePalette
        for (i, g) in classifierGroups.enumerated() {
            if g.members.contains(where: { $0.lowercased() == key }) {
                return palette[i % palette.count]
            }
        }
        return nil
    }

    /// Color of the largest classifier group, used for the ambient panel glow.
    private var dominantStanceColor: Color? {
        guard shouldShowStanceColors, !classifierGroups.isEmpty else { return nil }
        guard let largest = classifierGroups.enumerated().max(by: { $0.element.members.count < $1.element.members.count }) else { return nil }
        let palette = stancePalette
        return palette[largest.offset % palette.count]
    }

    /// Border color for the outer panel. Ambient glow, when on and a stance is
    /// known, overrides the default white outline with the dominant stance hue.
    private var panelBorderColor: Color {
        if settings.ambientStanceGlow.isOn, let glow = dominantStanceColor {
            return glow.opacity(settings.ambientStanceGlow.opacity)
        }
        return Color.white.opacity(0.10)
    }

    private var panelBorderWidth: CGFloat {
        if settings.ambientStanceGlow.isOn, dominantStanceColor != nil {
            return settings.ambientStanceGlow.borderWidth
        }
        return 1
    }

    private func promptTypeFor(problemType: ProblemType) -> String {
        switch problemType {
        case .generalQuestion:
            return "general"
        case .multipleChoiceSingle, .multipleChoiceMulti:
            return "mcq"
        }
    }

    private var inputContentOpacity: Double {
        phase == .loading ? 0.25 : 1.0
    }

    private var sendButtonAccentOpacity: Double {
        settings.accentColorChoice == .mono ? 0.14 : 0.22
    }

    private var selectedAdvocateBorderOpacity: Double {
        settings.accentColorChoice == .mono ? 0.35 : 0.55
    }

    private var inputContentOffset: CGFloat {
        phase == .loading ? 10 : 0
    }

    private func triggerResolveRound(source: String) {
        let correlationId = UUID().uuidString
        lastResolveCorrelationId = correlationId
        logResolve(event: "resolve-triggered", source: source, correlationId: correlationId, conversationId: currentConversationId, messageId: lastUserMessageId, roundIndex: roundIndex)

        guard canResolve else {
            logResolve(event: "resolve-blocked-canResolve", source: source, correlationId: correlationId, conversationId: currentConversationId, messageId: lastUserMessageId, roundIndex: roundIndex)
            return
        }
        guard !isArbiterThinking else {
            logResolve(event: "resolve-blocked-arbiterThinking", source: source, correlationId: correlationId, conversationId: currentConversationId, messageId: lastUserMessageId, roundIndex: roundIndex)
            return
        }

        roundIndex += 1
        isArbiterThinking = true
        isResolveRoundInFlight = true
        arbiterSummaryText = ""

        logResolve(event: "resolve-started", source: source, correlationId: correlationId, conversationId: currentConversationId, messageId: lastUserMessageId, roundIndex: roundIndex)

        Task {
            await performResolveRound(correlationId: correlationId, source: source)
        }
    }

    private var phaseString: String {
        switch phase {
        case .composing: return "composing"
        case .loading: return "loading"
        case .responded: return "responded"
        }
    }

    // This is the only “pre-resolve / debated question” UI we keep.
    private var lastSentPanel: some View {
        Group {
            if !lastSentText.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)

                    Text(lastSentText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: settings.cornerRadius(16), style: .continuous)
                .fill(settings.panelTranslucency.material)
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(16), style: .continuous)
                        .strokeBorder(panelBorderColor, lineWidth: panelBorderWidth)
                )
                .shadow(color: Color.black.opacity(0.30), radius: 14, x: 0, y: 0)

            VStack(spacing: 12) {
                if phase != .composing {
                    topArea
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                inputBar
            }
            .padding(18)
            .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius(16), style: .continuous))

            hiddenKeyboardShortcuts

            if let toast {
                toastView(toast)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        )
                    )
            }
        }
        .tint(settings.resolvedAccentColor)
        .environment(\.resolveChatPhase, phaseString)
        .frame(
            width: currentPanelWidth,
            height: phase == .composing ? baseHeight : expandedHeight
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }

            if initialConversationId == nil && phase == .composing {
                problemType = settings.defaultProblemType
            }

            if let initialConversationId {
                currentConversationId = initialConversationId
                Task { await loadConversation(conversationId: initialConversationId) }
            }
        }
        .onChange(of: phase) { newPhase in
            if newPhase == .composing {
                selectedAdvocateId = nil
            }
            let height = newPhase == .composing ? baseHeight : expandedHeight
            let width = newPhase == .composing ? baseWidth : currentPanelWidth
            CommandPanelController.shared.setSize(width: width, height: height, animated: !settings.reducedMotion)
        }
        .onChange(of: selectedAdvocateId) { _ in
            CommandPanelController.shared.setWidth(currentPanelWidth, animated: !settings.reducedMotion)
        }
        .onChange(of: settings.panelSize) { _ in
            // Live-resize the panel when the user changes the size preset.
            let height = phase == .composing ? baseHeight : expandedHeight
            let width = phase == .composing ? baseWidth : currentPanelWidth
            CommandPanelController.shared.setSize(width: width, height: height, animated: !settings.reducedMotion)
        }
        .onReceive(NotificationCenter.default.publisher(for: resolveRoundNotification)) { _ in
            guard let panelController else { return }
            guard CommandPanelController.shared === panelController else { return }
            triggerResolveRound(source: "notification")
        }
        .onReceive(NotificationCenter.default.publisher(for: previousRoundNotification)) { _ in
            guard let panelController, CommandPanelController.shared === panelController else { return }
            guard canGoBackRound else { return }
            goToPreviousRound()
        }
        .onReceive(NotificationCenter.default.publisher(for: nextRoundNotification)) { _ in
            guard let panelController, CommandPanelController.shared === panelController else { return }
            guard canGoForwardRound else { return }
            goToNextRound()
        }
        .onReceive(NotificationCenter.default.publisher(for: closeAdvocateDrawerNotification)) { _ in
            guard let panelController, CommandPanelController.shared === panelController else { return }
            selectedAdvocateId = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: copyArbiterSummaryNotification)) { _ in
            guard let panelController, CommandPanelController.shared === panelController else { return }
            copyArbiterSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: exportChatMarkdownNotification)) { _ in
            guard let panelController, CommandPanelController.shared === panelController else { return }
            exportChatAsMarkdown()
        }
    }

    private var topArea: some View {
        Group {
            switch submittedProblemType {
            case .generalQuestion:
                generalQuestionArea
            case .multipleChoiceSingle, .multipleChoiceMulti:
                multipleChoiceArea
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: settings.cornerRadius(14), style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: settings.cornerRadius(14), style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var multipleChoiceArea: some View {
        HStack(alignment: .top, spacing: 12) {
            leftColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            rightColumn
                .frame(width: advocateColumnWidth)

            if let selected = selectedAdvocate {
                advocateDrawer(for: selected)
                    .frame(width: drawerWidth)
                    .transition(.opacity)
            }
        }
    }

    private var generalQuestionArea: some View {
        HStack(alignment: .top, spacing: 12) {
            generalQuestionLeftColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            generalQuestionRightColumn
                .frame(width: advocateColumnWidth)

            if let selected = selectedAdvocate {
                advocateDrawer(for: selected)
                    .frame(width: drawerWidth)
                    .transition(.opacity)
            }
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 12) {
            lastSentPanel

            Divider()
                .overlay(Color.white.opacity(0.10))

            headerRow

            Group {
                switch phase {
                case .loading:
                    VStack(spacing: 10) {
                        OnboardingBreathingDot(diameter: 22)

                        Text("Advocates are debating…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .responded:
                    Group {
                        if isArbiterThinking || arbiterSummaryText.isEmpty {
                            VStack(spacing: 10) {
                                OnboardingBreathingDot(diameter: 22)

                                if isResolveRoundInFlight {
                                    Text("Advocates are debating…")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                arbiterSummaryView(text: arbiterSummaryText)
                                    .font(.system(size: settings.arbiterTextSize.pointSize, weight: .regular, design: settings.arbiterFont.design))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 8)
                            }
                        }
                    }

                case .composing:
                    EmptyView()
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                roundNavigationView
            }

            HStack {
                Spacer()
                Text(problemTypeShortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if showHistoricalEmptyState {
                Text("No saved outputs for this chat.")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(advocates.enumerated()), id: \.element.id) { idx, advocate in
                    Button {
                        toggleAdvocateSelection(advocate)
                    } label: {
                        AdvocateCardView(
                            title: advocate.providerName,
                            summary: advocate.summary,
                            isSelected: selectedAdvocateId == advocate.id,
                            accentColor: shouldShowStanceColors ? (stanceColor(for: advocate.provider) ?? providerAccentColors[advocate.provider]) : nil,
                            isLoading: isResolveRoundInFlight,
                            cornerRadius: settings.cornerRadius(10),
                            selectionTint: settings.resolvedAccentColor,
                            selectionTintOpacity: selectedAdvocateBorderOpacity,
                            summaryLineLimit: settings.advocateCardDensity.summaryLineLimit,
                            keyHint: (idx < 5 && settings.showKeyboardHintChips) ? "⌘ \(idx + 1)" : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var advocateColumnWidth: CGFloat {
        switch submittedProblemType {
        case .multipleChoiceSingle:
            return singleSelectAdvocateWidth
        case .multipleChoiceMulti:
            return multiSelectAdvocateWidth
        case .generalQuestion:
            return generalQuestionAdvocateWidth
        }
    }

    private var advocateOptions: [String]? {
        switch submittedProblemType {
        case .multipleChoiceSingle, .multipleChoiceMulti:
            return ["Option A", "Option B", "Option C", "Option D"]
        case .generalQuestion:
            return nil
        }
    }

    private var advocates: [AdvocateResult] {
        currentAdvocates
    }

    private var selectedAdvocate: AdvocateResult? {
        advocates.first { $0.id == selectedAdvocateId }
    }

    private func toggleAdvocateSelection(_ advocate: AdvocateResult) {
        if selectedAdvocateId == advocate.id {
            selectedAdvocateId = nil
        } else {
            selectedAdvocateId = advocate.id
        }
    }

    private var problemTypeShortLabel: String {
        switch submittedProblemType {
        case .multipleChoiceSingle:
            return "Single Select"
        case .multipleChoiceMulti:
            return "Multi Select"
        case .generalQuestion:
            return "General Question"
        }
    }

    private var problemTypeIcon: String {
        switch problemType {
        case .multipleChoiceSingle:
            return "checkmark.circle"
        case .multipleChoiceMulti:
            return "checklist"
        case .generalQuestion:
            return "questionmark.circle"
        }
    }

    private func advocateDrawer(for advocate: AdvocateResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(advocate.providerName)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                if settings.showKeyboardHintChips {
                    ResolveKeycap("⌘ esc")
                }

                Button {
                    selectedAdvocateId = nil
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
                .help("Close drawer (⌘ esc)")
            }

            Text("Detailed reasoning")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                Text(advocate.explanation)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var generalQuestionLeftColumn: some View {
        VStack(spacing: 12) {
            lastSentPanel

            Divider()
                .overlay(Color.white.opacity(0.10))

            headerRow

            Group {
                switch phase {
                case .loading:
                    VStack(spacing: 10) {
                        OnboardingBreathingDot(diameter: 22)

                        Text("Advocates are debating…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .responded:
                    Group {
                        if isArbiterThinking || arbiterSummaryText.isEmpty {
                            VStack(spacing: 10) {
                                OnboardingBreathingDot(diameter: 22)

                                if isResolveRoundInFlight {
                                    Text("Advocates are debating…")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                arbiterSummaryView(text: arbiterSummaryText)
                                    .font(.system(size: settings.arbiterTextSize.pointSize, weight: .regular, design: settings.arbiterFont.design))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 8)
                            }
                        }
                    }

                case .composing:
                    EmptyView()
                }
            }
        }
    }

    private var generalQuestionRightColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                roundNavigationView
            }

            HStack {
                Spacer()
                Text(problemTypeShortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if showHistoricalEmptyState {
                Text("No saved outputs for this chat.")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(advocates.enumerated()), id: \.element.id) { idx, advocate in
                            Button {
                                toggleAdvocateSelection(advocate)
                            } label: {
                                AdvocateThesisCardView(
                                    title: advocate.providerName,
                                    summary: advocate.summary,
                                    isSelected: selectedAdvocateId == advocate.id,
                                    accentColor: shouldShowStanceColors ? (stanceColor(for: advocate.provider) ?? providerAccentColors[advocate.provider]) : nil,
                                    isLoading: isResolveRoundInFlight,
                                    cornerRadius: settings.cornerRadius(10),
                                    selectionTint: settings.resolvedAccentColor,
                                    selectionTintOpacity: selectedAdvocateBorderOpacity,
                                    summaryLineLimit: settings.advocateCardDensity.thesisLineLimit,
                                    keyHint: (idx < 5 && settings.showKeyboardHintChips) ? "⌘ \(idx + 1)" : nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var displayedRoundCount: Int {
        max(roundSnapshots.count, 1)
    }

    private var displayedRoundNumber: Int {
        roundSnapshots.isEmpty ? 1 : viewedRoundIndex + 1
    }

    /// Static lookup for ⌘1–⌘5 advocate-drawer shortcuts. Indexing into a
    /// fixed array keeps the compiler happy across Swift versions and
    /// hard-caps the panel at 5 advocate slots.
    private static let advocateNumberKeys: [KeyEquivalent] = [
        KeyEquivalent("1"), KeyEquivalent("2"), KeyEquivalent("3"),
        KeyEquivalent("4"), KeyEquivalent("5")
    ]

    /// Hidden buttons that capture chat-only keyboard shortcuts. Each one
    /// is a 0×0 invisible button — SwiftUI still routes the matching key
    /// chord to its action when the chat panel is the key window. Local
    /// scope: pressing these chords in another app does nothing to Resolve.
    @ViewBuilder
    private var hiddenKeyboardShortcuts: some View {
        Group {
            // ⌘ B — go home (only when this chat was opened with a back
            // affordance, e.g. via Past Chats).
            Button("") { onBack?() }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(onBack == nil)

            // ⌘ [ — previous resolve round
            Button("") { goToPreviousRound() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!canGoBackRound)

            // ⌘ ] — next resolve round
            Button("") { goToNextRound() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!canGoForwardRound)

            // ⌘ ⎋ — close advocate drawer
            Button("") { selectedAdvocateId = nil }
                .keyboardShortcut(.escape, modifiers: .command)
                .disabled(selectedAdvocateId == nil)

            // ⌘ 1–5 — open the Nth advocate's drawer
            ForEach(0..<5, id: \.self) { idx in
                Button("") {
                    let list = advocates
                    guard idx < list.count else { return }
                    selectedAdvocateId = list[idx].id
                }
                .keyboardShortcut(Self.advocateNumberKeys[idx], modifiers: .command)
                .disabled(idx >= advocates.count)
            }

            // ⌘ ⇧ C — copy arbiter summary to clipboard
            Button("") { copyArbiterSummary() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(arbiterSummaryText.isEmpty)

            // ⌘ ⇧ E — export the entire chat as markdown
            Button("") { exportChatAsMarkdown() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(arbiterSummaryText.isEmpty || lastSentText.isEmpty)

            // ⌘ G — cycle the ambient stance glow setting
            Button("") { cycleAmbientStanceGlow() }
                .keyboardShortcut("g", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    /// Renders the floating toast chip (used for "Summary copied",
    /// "Exported to Downloads", etc.).
    private func toastView(_ toast: ChatToast) -> some View {
        let iconColor: Color = {
            if toast.iconName.contains("exclamationmark") { return .orange }
            if toast.iconName.contains("checkmark") { return .green }
            return .secondary
        }()
        return HStack(spacing: 6) {
            Image(systemName: toast.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(toast.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 2)
    }

    /// Show the toast for ~1.3s. Re-firing while one is already up
    /// re-arms the dismiss timer instead of stacking dismissals.
    private func showToast(message: String, iconName: String = "checkmark.circle.fill") {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            toast = ChatToast(message: message, iconName: iconName)
        }
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) {
                toast = nil
            }
        }
    }

    private func copyArbiterSummary() {
        guard !arbiterSummaryText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(arbiterSummaryText, forType: .string)
        showToast(message: "Summary copied")
    }

    private func cycleAmbientStanceGlow() {
        let next = settings.cycleAmbientStanceGlow()
        showToast(message: "Stance glow: \(next.displayName)", iconName: "circle.dashed")
    }

    private func exportChatAsMarkdown() {
        guard !arbiterSummaryText.isEmpty, !lastSentText.isEmpty else { return }

        var md = "# Resolve Chat\n\n"
        md += "## Question\n\n"
        md += "\(lastSentText)\n\n"
        md += "## Arbiter Summary\n\n"
        md += "\(arbiterSummaryText)\n\n"

        if !advocates.isEmpty {
            md += "## Advocate Responses\n\n"
            for advocate in advocates {
                md += "### \(advocate.providerName)\n\n"
                if !advocate.summary.isEmpty {
                    md += "**Summary:** \(advocate.summary)\n\n"
                }
                if !advocate.explanation.isEmpty {
                    md += "\(advocate.explanation)\n\n"
                }
            }
        }

        // No NSSavePanel — Resolve is LSUIElement, and the modal
        // file dialog interacts badly with the floating panel + the
        // hide-on-focus-loss observer (manifests as a frozen app).
        // Just write straight to ~/Downloads with a timestamped
        // filename and confirm via the toast.
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let downloads else {
            print("ChatPaletteView.exportChatAsMarkdown: no Downloads directory")
            showToast(message: "Couldn't find Downloads", iconName: "exclamationmark.triangle.fill")
            return
        }

        let stampFormatter = DateFormatter()
        stampFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = stampFormatter.string(from: Date())
        let url = downloads.appendingPathComponent("resolve-chat-\(stamp).md")

        do {
            try md.write(to: url, atomically: true, encoding: .utf8)
            showToast(message: "Exported to Downloads")
        } catch {
            print("ChatPaletteView.exportChatAsMarkdown: write failed \(error.localizedDescription)")
            showToast(message: "Export failed", iconName: "exclamationmark.triangle.fill")
        }
    }

    private var roundNavigationView: some View {
        HStack(spacing: 6) {
            Button {
                goToPreviousRound()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(6), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(6), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .opacity(canGoBackRound ? 1.0 : 0.35)
            .disabled(!canGoBackRound)
            .help("Previous round (⌘ [)")

            if canGoBackRound && settings.showKeyboardHintChips {
                ResolveKeycap("⌘ [")
            }

            Text("\(displayedRoundNumber)/\(displayedRoundCount)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 26)

            if canGoForwardRound && settings.showKeyboardHintChips {
                ResolveKeycap("⌘ ]")
            }

            Button {
                goToNextRound()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(6), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(6), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .opacity(canGoForwardRound ? 1.0 : 0.35)
            .disabled(!canGoForwardRound)
            .help("Next round (⌘ ])")
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("Arbiter’s Summary")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Text(resolvesRemainingText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Button {
                triggerResolveRound(source: "button")
            } label: {
                HStack(spacing: 6) {
                    Text("Resolve")

                    if canResolve && !isArbiterThinking && settings.showKeyboardHintChips {
                        ResolveKeycap("⌘ ⇧ R")
                    }
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(9), style: .continuous)
                    .fill(canResolve ? settings.resolvedAccentColor.opacity(resolveButtonAccentOpacity) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(9), style: .continuous)
                    .strokeBorder(canResolve ? settings.resolvedAccentColor.opacity(resolveButtonBorderOpacity) : Color.white.opacity(0.10), lineWidth: 1)
            )
            .opacity(canResolve ? 1.0 : 0.45)
            .disabled(!canResolve)
        }
    }

    private var resolveButtonAccentOpacity: Double {
        settings.accentColorChoice == .mono ? 0.10 : 0.20
    }

    private var resolveButtonBorderOpacity: Double {
        settings.accentColorChoice == .mono ? 0.10 : 0.40
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .help("Go home (⌘ B)")
                .onHover { isBackButtonHovering = $0 }
                // Hover-only chip: overlay alignment + offset keeps it
                // out of the layout flow so the button stays 32×32 and
                // aligned with the rest of the input bar. Fades in on
                // hover, fades out otherwise.
                .overlay(alignment: .top) {
                    if settings.showKeyboardHintChips {
                        ResolveKeycap("⌘ B")
                            .fixedSize()
                            .offset(y: -20)
                            .opacity(isBackButtonHovering ? 1 : 0)
                            .animation(.easeOut(duration: 0.12), value: isBackButtonHovering)
                            .allowsHitTesting(false)
                    }
                }
            }

            Button(action: startNewConversation) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)

                TextField("Ask Resolve…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium))
                    .focused($focused)
                    .disabled(phase == .loading)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(12), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )

            Menu {
                Button {
                    problemType = .multipleChoiceSingle
                } label: {
                    Label("Multiple Choice – Single Select", systemImage: "checkmark.circle")
                }

                Button {
                    problemType = .multipleChoiceMulti
                } label: {
                    Label("Multiple Choice – Multi Select", systemImage: "checklist")
                }

                Button {
                    problemType = .generalQuestion
                } label: {
                    Label("General Question", systemImage: "questionmark.circle")
                }
            } label: {
                Image(systemName: problemTypeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(9), style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: settings.cornerRadius(9), style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32, height: 32)
            .fixedSize()

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                    .fill(settings.resolvedAccentColor.opacity(canSend ? sendButtonAccentOpacity : 0.06))
            )
            .opacity(canSend ? 1.0 : 0.55)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Send (⌘ ↵)")
            .onHover { isSendButtonHovering = $0 }
            // Hover-only chip floats above via overlay + offset so the
            // input bar's row stays the same height as before.
            .overlay(alignment: .top) {
                if settings.showKeyboardHintChips {
                    ResolveKeycap("⌘ ↵")
                        .fixedSize()
                        .offset(y: -20)
                        .opacity(isSendButtonHovering ? 1 : 0)
                        .animation(.easeOut(duration: 0.12), value: isSendButtonHovering)
                        .allowsHitTesting(false)
                }
            }

            InlineCloseButton()
        }
        .opacity(inputContentOpacity)
        .offset(y: inputContentOffset)
        .animation(settings.animation(.easeInOut(duration: 0.2)), value: phase)
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, phase != .loading else { return }

        lastSentText = trimmed
        submittedProblemType = problemType
        lastPromptTypeForBackend = promptTypeFor(problemType: problemType)

        withAnimation(settings.animation(.easeInOut(duration: 0.2))) {
            text = ""
            phase = .loading
        }

        focused = false

        Task {
            await MainActor.run {
                arbiterSummaryText = ""
                isArbiterThinking = false
                roundIndex = 0
                isResolveRoundInFlight = false
                advocateResults = []
                classifierGroups = []
                mcqDisagreement = nil
                showHistoricalEmptyState = false
                allowPlaceholderAdvocates = true
                roundSnapshots = []
                viewedRoundIndex = 0
            }

            do {
                // Pass the user's prompt so a brand-new conversation
                // gets a readable title at creation time. If the
                // conversation already exists, the title is left
                // alone — explicit renames go through a separate path.
                let conversationId = try await ensureConversationId(autoTitleFrom: trimmed)
                let response = try await api.postMessage(
                    conversationId: conversationId,
                    content: trimmed,
                    promptType: lastPromptTypeForBackend,
                    summaryFormat: nil,
                    enabledAdvocates: settings.enabledAdvocateBackendKeys,
                    arbiterStyle: settings.arbiterStyle.rawValue
                )

                await MainActor.run {
                    currentConversationId = conversationId
                    lastUserMessageId = response.message.id
                    applyRunResult(response.run)
                    focused = true
                }
            } catch {
                await MainActor.run {
                    arbiterSummaryText = "Request failed: \(error.localizedDescription)"
                    isArbiterThinking = false
                    withAnimation(settings.animation(.easeInOut(duration: 0.25))) {
                        phase = .responded
                    }
                    focused = true
                }
            }
        }
    }

    private func performResolveRound(correlationId: String, source: String) async {
        let (conversationId, messageId, promptType, advocateKeys, arbiterStyleValue) = await MainActor.run {
            (currentConversationId, lastUserMessageId, lastPromptTypeForBackend, settings.enabledAdvocateBackendKeys, settings.arbiterStyle.rawValue)
        }

        guard let conversationId, let messageId else {
            await MainActor.run {
                arbiterSummaryText = "Nothing to resolve yet."
                isArbiterThinking = false
                isResolveRoundInFlight = false
                logResolve(event: "resolve-missing-ids", source: source, correlationId: correlationId, conversationId: conversationId, messageId: messageId, roundIndex: roundIndex)
            }
            return
        }

        await MainActor.run {
            logResolve(event: "resolve-request", source: source, correlationId: correlationId, conversationId: conversationId, messageId: messageId, roundIndex: roundIndex)
        }

        do {
            let response = try await api.resolve(
                conversationId: conversationId,
                messageId: messageId,
                promptType: promptType,
                summaryFormat: nil,
                enabledAdvocates: advocateKeys,
                arbiterStyle: arbiterStyleValue
            )

            await MainActor.run {
                applyRunResult(response.run)
                logResolve(event: "resolve-response", source: source, correlationId: correlationId, conversationId: conversationId, messageId: messageId, roundIndex: roundIndex, runId: response.run.runId)
            }
        } catch {
            await MainActor.run {
                arbiterSummaryText = "Request failed: \(error.localizedDescription)"
                isArbiterThinking = false
                isResolveRoundInFlight = false
                logResolve(event: "resolve-error: \(error.localizedDescription)", source: source, correlationId: correlationId, conversationId: conversationId, messageId: messageId, roundIndex: roundIndex)
            }
        }
    }

    private func arbiterSummaryView(text: String) -> Text {
        let segments = parseArbiterBoldSegments(text)
        var output = Text("")
        for segment in segments {
            switch segment {
            case .normal(let value):
                output = output + Text(value)
            case .bold(let value):
                output = output + emphasisText(value)
            }
        }
        return output
    }

    private func emphasisText(_ value: String) -> Text {
        switch settings.boldEmphasisStyle {
        case .bold:
            return Text(value).bold()
        case .boldColored:
            return Text(value).bold().foregroundColor(settings.resolvedAccentColor)
        case .underline:
            return Text(value).underline()
        }
    }

    private enum ArbiterBoldSegment {
        case normal(String)
        case bold(String)
    }

    private func parseArbiterBoldSegments(_ input: String) -> [ArbiterBoldSegment] {
        if input.contains("<bold>") {
            return parseTagBoldSegments(input, openTag: "<bold>", closeTag: "</bold>")
        }
        if input.contains("***") {
            return parseMarkerBoldSegments(input, marker: "***")
        }
        if input.contains("**") {
            return parseMarkerBoldSegments(input, marker: "**")
        }
        return [.normal(input)]
    }

    private func parseTagBoldSegments(_ input: String, openTag: String, closeTag: String) -> [ArbiterBoldSegment] {
        var segments: [ArbiterBoldSegment] = []
        var index = input.startIndex

        func appendNormal(_ value: String) {
            guard !value.isEmpty else { return }
            segments.append(.normal(value))
        }

        func appendBold(_ value: String) {
            guard !value.isEmpty else { return }
            segments.append(.bold(value))
        }

        while index < input.endIndex {
            guard let open = input[index...].range(of: openTag) else {
                appendNormal(String(input[index...]))
                break
            }

            appendNormal(String(input[index..<open.lowerBound]))
            let afterOpen = open.upperBound

            guard let close = input[afterOpen...].range(of: closeTag) else {
                appendNormal(openTag + String(input[afterOpen...]))
                break
            }

            appendBold(String(input[afterOpen..<close.lowerBound]))
            index = close.upperBound
        }

        return segments
    }

    private func parseMarkerBoldSegments(_ input: String, marker: String) -> [ArbiterBoldSegment] {
        var segments: [ArbiterBoldSegment] = []
        var index = input.startIndex

        func appendNormal(_ value: String) {
            guard !value.isEmpty else { return }
            segments.append(.normal(value))
        }

        func appendBold(_ value: String) {
            guard !value.isEmpty else { return }
            segments.append(.bold(value))
        }

        while index < input.endIndex {
            guard let open = input[index...].range(of: marker) else {
                appendNormal(String(input[index...]))
                break
            }

            appendNormal(String(input[index..<open.lowerBound]))
            let afterOpen = open.upperBound

            guard let close = input[afterOpen...].range(of: marker) else {
                appendNormal(marker + String(input[afterOpen...]))
                break
            }

            appendBold(String(input[afterOpen..<close.lowerBound]))
            index = close.upperBound
        }

        return segments
    }
}

private extension ChatPaletteView {

    @MainActor
    func startNewConversation() {
        currentConversationId = nil
        lastUserMessageId = nil
        lastSentText = ""
        arbiterSummaryText = ""
        advocateResults = []
        classifierGroups = []
        mcqDisagreement = nil
        roundIndex = 0
        isResolveRoundInFlight = false
        isArbiterThinking = false
        showHistoricalEmptyState = false
        allowPlaceholderAdvocates = true
        roundSnapshots = []
        viewedRoundIndex = 0
        problemType = settings.defaultProblemType
        withAnimation(settings.animation(.easeInOut(duration: 0.2))) {
            phase = .composing
        }
        focused = true
    }

    @MainActor
    func logResolveState(context: String, conversationId: UUID, persistedResolveCount: Int?) {
        print("ChatPaletteView.resolveState(\(context)): conversationId=\(conversationId) persistedResolveCount=\(persistedResolveCount ?? -1) resolvesUsed=\(resolvesUsed) remaining=\(resolvesRemaining) canResolve=\(canResolve)")
    }

    private static let resolveLogFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func logResolve(
        event: String,
        source: String,
        correlationId: String,
        conversationId: UUID?,
        messageId: UUID?,
        roundIndex: Int,
        runId: UUID? = nil
    ) {
        let timestamp = Self.resolveLogFormatter.string(from: Date())
        print("ResolveTrace \(timestamp) event=\(event) source=\(source) correlationId=\(correlationId) conversationId=\(conversationId?.uuidString ?? "nil") messageId=\(messageId?.uuidString ?? "nil") roundIndex=\(roundIndex) runId=\(runId?.uuidString ?? "nil")")
    }

    @MainActor
    func applyRunResult(_ run: RunResult) {
        arbiterSummaryText = arbiterText(from: run.arbiterOutput) ?? "No response returned."
        advocateResults = mapAdvocates(from: run)
        classifierGroups = run.classifierOutput?.outputJson.groups ?? []
        mcqDisagreement = run.mcqDisagreement
        lastPromptTypeForBackend = run.promptType ?? lastPromptTypeForBackend

        if let promptType = run.promptType?.lowercased() {
            if promptType.contains("multi") {
                submittedProblemType = .multipleChoiceMulti
            } else if promptType.contains("single") {
                submittedProblemType = .multipleChoiceSingle
            } else if promptType.contains("mcq") {
                submittedProblemType = .multipleChoiceSingle
            } else {
                submittedProblemType = .generalQuestion
            }
        }

        showHistoricalEmptyState = false
        allowPlaceholderAdvocates = true
        isArbiterThinking = false
        isResolveRoundInFlight = false

        let snapshot = RoundSnapshot(
            runId: run.runId,
            arbiterSummaryText: arbiterSummaryText,
            advocateResults: advocateResults,
            classifierGroups: classifierGroups,
            mcqDisagreement: mcqDisagreement,
            submittedProblemType: submittedProblemType,
            lastPromptTypeForBackend: lastPromptTypeForBackend
        )
        roundSnapshots.append(snapshot)
        viewedRoundIndex = roundSnapshots.count - 1

        withAnimation(settings.animation(.easeInOut(duration: 0.2))) {
            phase = .responded
        }

        // Background notification: only when the user opted in AND the
        // panel is hidden. If they're looking at the chat already, the
        // toast/UI updates are feedback enough.
        let notifyEnabled = settings.notifyOnResolveComplete
        let panelHidden = !CommandPanelManager.shared.hasVisiblePanel
        print("ChatPaletteView: round-complete notif gate — enabled=\(notifyEnabled) panelHidden=\(panelHidden)")
        if notifyEnabled, panelHidden {
            let roundIdx = run.runIndex ?? max(roundSnapshots.count - 1, 0)
            let stageLabel = roundIdx == 0 ? "Initial debate done" : "Resolve round \(roundIdx)"
            ResolveNotifications.shared.postStageComplete(
                stage: stageLabel,
                bodyPreview: arbiterSummaryText
            )
        }
    }

    @MainActor
    func goToPreviousRound() {
        guard viewedRoundIndex > 0 else { return }
        viewedRoundIndex -= 1
        applySnapshot(roundSnapshots[viewedRoundIndex])
    }

    @MainActor
    func goToNextRound() {
        guard viewedRoundIndex < roundSnapshots.count - 1 else { return }
        viewedRoundIndex += 1
        applySnapshot(roundSnapshots[viewedRoundIndex])
    }

    @MainActor
    func showEmptyHistoricalState(hasLastUser: Bool) {
        arbiterSummaryText = "No saved outputs for this chat."
        advocateResults = []
        classifierGroups = []
        mcqDisagreement = nil
        showHistoricalEmptyState = true
        allowPlaceholderAdvocates = false
        isArbiterThinking = false
        isResolveRoundInFlight = false
        withAnimation(settings.animation(.easeInOut(duration: 0.2))) {
            phase = hasLastUser ? .responded : .composing
        }
    }

    @MainActor
    private func applySnapshot(_ snapshot: RoundSnapshot) {
        arbiterSummaryText = snapshot.arbiterSummaryText
        advocateResults = snapshot.advocateResults
        classifierGroups = snapshot.classifierGroups
        mcqDisagreement = snapshot.mcqDisagreement
        submittedProblemType = snapshot.submittedProblemType
        lastPromptTypeForBackend = snapshot.lastPromptTypeForBackend
    }

    private func arbiterText(from output: RunResult.ArbiterOutput?) -> String? {
        let detailed = output?.detailedResponse?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !detailed.isEmpty { return detailed }

        let content = output?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !content.isEmpty { return content }

        let summary = output?.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !summary.isEmpty { return summary }

        let text = output?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty { return text }

        return nil
    }

    func isCompletedRunStatus(_ status: String?) -> Bool {
        guard let status = status?.lowercased() else { return false }
        return ["complete", "completed", "succeeded", "success", "done"].contains(status)
    }

    /// Pure-ish snapshot factory. Mirrors the per-run derivations done by
    /// `applyRunResult` so historical hydration can build snapshots for
    /// many runs without thrashing UI state in between.
    @MainActor
    func makeRoundSnapshot(from run: RunResult) -> RoundSnapshot {
        let arbiter = arbiterText(from: run.arbiterOutput) ?? "No response returned."
        let advocates = mapAdvocates(from: run)
        let groups = run.classifierOutput?.outputJson.groups ?? []

        let derivedProblemType: ProblemType
        if let pt = run.promptType?.lowercased() {
            if pt.contains("multi") {
                derivedProblemType = .multipleChoiceMulti
            } else if pt.contains("single") || pt.contains("mcq") {
                derivedProblemType = .multipleChoiceSingle
            } else {
                derivedProblemType = .generalQuestion
            }
        } else {
            derivedProblemType = submittedProblemType
        }

        return RoundSnapshot(
            runId: run.runId,
            arbiterSummaryText: arbiter,
            advocateResults: advocates,
            classifierGroups: groups,
            mcqDisagreement: run.mcqDisagreement,
            submittedProblemType: derivedProblemType,
            lastPromptTypeForBackend: run.promptType ?? lastPromptTypeForBackend
        )
    }

    func ensureConversationId(autoTitleFrom prompt: String? = nil) async throws -> UUID {
        let existing = await MainActor.run { currentConversationId }
        if let existing { return existing }
        let title = prompt.flatMap { Self.autoTitle(fromPrompt: $0) }
        let conversation = try await api.createConversation(title: title)
        await MainActor.run {
            currentConversationId = conversation.id
        }
        return conversation.id
    }

    /// Build a short, readable title for a brand-new conversation from
    /// the user's opening prompt. Trims whitespace, collapses internal
    /// newlines into a space, and caps to ~60 characters with an
    /// ellipsis. Returns nil if the prompt is empty after trimming.
    static func autoTitle(fromPrompt prompt: String) -> String? {
        let collapsed = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        let limit = 60
        guard collapsed.count > limit else { return collapsed }
        let idx = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<idx]).trimmingCharacters(in: .whitespaces) + "…"
    }

    func loadConversation(conversationId: UUID) async {
        do {
            let detail = try await api.getConversation(id: conversationId)
            let hasLastUser = detail.messages.contains { $0.role.lowercased() == "user" }
            let persistedResolveCount = detail.conversation.resolveCount
            await MainActor.run {
                currentConversationId = conversationId
                classifierGroups = []
                mcqDisagreement = nil
                roundIndex = min(persistedResolveCount, maxRounds)
                let lastUser = detail.messages.last(where: { $0.role.lowercased() == "user" })
                lastUserMessageId = lastUser?.id
                lastSentText = lastUser?.content ?? ""
                if let pt = lastUser?.promptType {
                    lastPromptTypeForBackend = pt
                }
                arbiterSummaryText = ""
                isArbiterThinking = false
                isResolveRoundInFlight = false
                showHistoricalEmptyState = false
                allowPlaceholderAdvocates = true
                roundSnapshots = []
                viewedRoundIndex = 0
            }

            print("ChatPaletteView.loadConversation: conversationId=\(conversationId)")
            await MainActor.run {
                logResolveState(context: "historical-load", conversationId: conversationId, persistedResolveCount: persistedResolveCount)
            }

            // Hydrate every completed run for the latest user message so
            // back-scroll through prior rounds works after reopening a
            // chat from history. Falls back to the empty-historical-state
            // path if there's no user message or no completed runs to show.
            let userMessage = detail.messages.last(where: { $0.role.lowercased() == "user" })
            guard let userMessageId = userMessage?.id else {
                print("ChatPaletteView.loadConversation: no user message in history")
                await MainActor.run {
                    showEmptyHistoricalState(hasLastUser: hasLastUser)
                    logResolveState(context: "historical-no-user", conversationId: conversationId, persistedResolveCount: persistedResolveCount)
                }
                return
            }

            do {
                let runs = try await api.listRuns(conversationId: conversationId, messageId: userMessageId)
                let completedRuns = runs.filter { isCompletedRunStatus($0.status) }
                print("ChatPaletteView.loadConversation: fetched \(runs.count) run(s), \(completedRuns.count) completed, messageId=\(userMessageId)")

                if completedRuns.isEmpty {
                    await MainActor.run {
                        showEmptyHistoricalState(hasLastUser: hasLastUser)
                        logResolveState(context: "historical-no-completed-runs", conversationId: conversationId, persistedResolveCount: persistedResolveCount)
                    }
                    return
                }

                await MainActor.run {
                    let snapshots = completedRuns.map { makeRoundSnapshot(from: $0) }
                    roundSnapshots = snapshots
                    let lastIndex = snapshots.count - 1
                    viewedRoundIndex = lastIndex
                    applySnapshot(snapshots[lastIndex])
                    showHistoricalEmptyState = false
                    allowPlaceholderAdvocates = true
                    isArbiterThinking = false
                    isResolveRoundInFlight = false
                    withAnimation(settings.animation(.easeInOut(duration: 0.2))) {
                        phase = .responded
                    }
                    logResolveState(context: "historical-hydrated", conversationId: conversationId, persistedResolveCount: persistedResolveCount)
                }
                print("ChatPaletteView.loadConversation: historical hydration succeeded with \(completedRuns.count) round(s)")
            } catch {
                await MainActor.run {
                    showEmptyHistoricalState(hasLastUser: hasLastUser)
                }
                print("ChatPaletteView.loadConversation: historical hydration failed: \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                lastUserMessageId = nil
                classifierGroups = []
                mcqDisagreement = nil
                lastSentText = ""
                arbiterSummaryText = ""
                showHistoricalEmptyState = false
                allowPlaceholderAdvocates = true
                roundSnapshots = []
                viewedRoundIndex = 0
                withAnimation(settings.animation(.easeInOut(duration: 0.2))) {
                    phase = .composing
                }
            }
        }
    }

    func mapAdvocates(from run: RunResult) -> [AdvocateResult] {
        run.advocateOutputs.map { output in
            let provider = mapProvider(output.provider, advocateKey: output.advocateKey)

            let content = (output.content ?? output.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let detailed = (output.detailedResponse ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = (output.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let parsed = content.isEmpty ? nil : AdvocateClient.parseResponse(content)
            let explanation = !detailed.isEmpty ? detailed : (parsed?.explanation ?? (content.isEmpty ? "No response." : content))
            let finalSummary = !summary.isEmpty ? summary : (parsed?.summary ?? "Summary could not be parsed")

            return AdvocateResult(
                provider: provider,
                explanation: explanation,
                summary: finalSummary
            )
        }
    }

    func mapProvider(_ value: String?, advocateKey: String) -> AdvocateProvider {
        let normalized = (value ?? advocateKey).lowercased()
        if normalized.contains("openai") || normalized.contains("chatgpt") { return .openAI }
        if normalized.contains("anthropic") || normalized.contains("claude") { return .anthropic }
        if normalized.contains("gemini") || normalized.contains("google") { return .gemini }
        if normalized.contains("deepseek") { return .deepSeek }
        if normalized.contains("mistral") { return .mistral }
        return .openAI
    }
}

private extension ChatPaletteView {
    struct AdvocateCardView: View {
        let title: String
        let summary: String
        let isSelected: Bool
        let accentColor: Color?
        let isLoading: Bool
        let cornerRadius: CGFloat
        let selectionTint: Color
        let selectionTintOpacity: Double
        let summaryLineLimit: Int
        /// Pre-formatted "⌘ N" string. Nil means no chip is rendered —
        /// either because the card's index is past 5 or the user
        /// disabled keyboard hint chips in Settings.
        let keyHint: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if let keyHint {
                        ResolveKeycap(keyHint)
                    }

                    Spacer(minLength: 8)

                    if let accentColor {
                        Capsule(style: .continuous)
                            .fill(accentColor.opacity(0.85))
                            .frame(width: 70, height: 3)
                    }
                }

                Text(summary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(summaryLineLimit)
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
                        isSelected ? selectionTint.opacity(selectionTintOpacity) : Color.white.opacity(0.10),
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

    struct AdvocateThesisCardView: View {
        let title: String
        let summary: String
        let isSelected: Bool
        let accentColor: Color?
        let isLoading: Bool
        let cornerRadius: CGFloat
        let selectionTint: Color
        let selectionTintOpacity: Double
        let summaryLineLimit: Int
        /// Pre-formatted "⌘ N" string. Nil means no chip is rendered —
        /// either because the card's index is past 5 or the user
        /// disabled keyboard hint chips in Settings.
        let keyHint: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if let keyHint {
                        ResolveKeycap(keyHint)
                    }

                    Spacer(minLength: 8)

                    if let accentColor {
                        Capsule(style: .continuous)
                            .fill(accentColor.opacity(0.85))
                            .frame(width: 70, height: 3)
                    }
                }

                Text(summary)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(summaryLineLimit)
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
                        isSelected ? selectionTint.opacity(selectionTintOpacity) : Color.white.opacity(0.10),
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

    func fetchClaudeResponse(for prompt: String) async throws -> String {
        return "This endpoint is disabled. Resolve uses backend conversation endpoints only."
    }
}

private struct InlineCloseButton: View {
    @Environment(\.resolveCloseAction) private var closeAction
    @ObservedObject private var settings = UserSettingsStore.shared
    @State private var isHovering = false

    var body: some View {
        Group {
            if let closeAction {
                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isHovering ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.10 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(10), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .onHover { hovering in
                    isHovering = hovering
                }
                .animation(.easeOut(duration: 0.12), value: isHovering)
            }
        }
    }
}

private struct ResolveKeycap: View {
    let keys: String

    @ObservedObject private var settings = UserSettingsStore.shared

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: settings.cornerRadius(7), style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(7), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)

        ChatPaletteView(initialConversationId: nil)
            .frame(width: 620, height: 420)
    }
    .frame(width: 1000, height: 600)
}
