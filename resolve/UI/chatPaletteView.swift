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
                        ProgressView()
                            .controlSize(.regular)

                        Text("Advocates are debating…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .responded:
                    Group {
                        if isArbiterThinking || arbiterSummaryText.isEmpty {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.regular)

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
                ForEach(advocates) { advocate in
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
                            summaryLineLimit: settings.advocateCardDensity.summaryLineLimit
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
                        ProgressView()
                            .controlSize(.regular)

                        Text("Advocates are debating…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .responded:
                    Group {
                        if isArbiterThinking || arbiterSummaryText.isEmpty {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.regular)

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
                        ForEach(advocates) { advocate in
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
                                    summaryLineLimit: settings.advocateCardDensity.thesisLineLimit
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
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func copyArbiterSummary() {
        guard !arbiterSummaryText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(arbiterSummaryText, forType: .string)
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

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "resolve-chat.md"
        panel.canCreateDirectories = true
        panel.title = "Export chat"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? md.write(to: url, atomically: true, encoding: .utf8)
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
                let conversationId = try await ensureConversationId()
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

    func ensureConversationId() async throws -> UUID {
        let existing = await MainActor.run { currentConversationId }
        if let existing { return existing }
        let conversation = try await api.createConversation(title: nil)
        await MainActor.run {
            currentConversationId = conversation.id
        }
        return conversation.id
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

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

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

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

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
