import SwiftUI

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

    @FocusState private var focused: Bool
    @Environment(\.resolvePanelController) private var panelController

    private let api = BackendAPIClient()

    private let baseHeight: CGFloat = 140
    private let expandedHeight: CGFloat = 460
    private let baseWidth: CGFloat = 620
    private let expandedWidth: CGFloat = 760
    private let drawerWidth: CGFloat = 260
    private let singleSelectAdvocateWidth: CGFloat = 150
    private let multiSelectAdvocateWidth: CGFloat = 170
    private let generalQuestionAdvocateWidth: CGFloat = 230
    private let advocateTopPadding: CGFloat = 44
    private let maxRounds: Int = 2

    private var canSend: Bool {
        phase != .loading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDrawerOpen: Bool {
        selectedAdvocateId != nil
    }

    private var currentAdvocates: [AdvocateResult] {
        advocateResults.isEmpty ? AdvocateClient.placeholderResults : advocateResults
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
        phase == .responded &&
        !isArbiterThinking &&
        !isResolveRoundInFlight &&
        !classifierGroups.isEmpty
    }

    private var resolvesRemaining: Int {
        max(0, maxRounds - roundIndex)
    }

    private var resolvesRemainingText: String {
        "\(resolvesRemaining)/\(maxRounds) resolves remaining"
    }

    private var canResolve: Bool {
        currentConversationId != nil &&
        lastUserMessageId != nil &&
        roundIndex < maxRounds &&
        !isResolveRoundInFlight &&
        !isArbiterThinking &&
        phase == .responded &&
        hasDisagreement
    }

    private let stancePalette: [Color] = [.blue, .purple, .orange, .teal, .pink]

    private func stanceColor(for provider: AdvocateProvider) -> Color? {
        let key: String
        switch provider {
        case .openAI: key = "openai"
        case .anthropic: key = "anthropic"
        case .gemini: key = "gemini"
        case .deepSeek: key = "deepseek"
        case .mistral: key = "mistral"
        }

        for (i, g) in classifierGroups.enumerated() {
            if g.members.contains(where: { $0.lowercased() == key }) {
                return stancePalette[i % stancePalette.count]
            }
        }
        return nil
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

    private var inputContentOffset: CGFloat {
        phase == .loading ? 10 : 0
    }

    private func triggerResolveRound() {
        guard canResolve else { return }
        guard !isArbiterThinking else { return }

        roundIndex += 1
        isArbiterThinking = true
        isResolveRoundInFlight = true
        arbiterSummaryText = ""

        Task {
            await performResolveRound()
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10))
                )
                .shadow(radius: 16)

            VStack(spacing: 12) {
                if phase != .composing {
                    topArea
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                inputBar
            }
            .padding(18)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .environment(\.resolveChatPhase, phaseString)
        .frame(
            width: currentPanelWidth,
            height: phase == .composing ? baseHeight : expandedHeight
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
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
            CommandPanelController.shared.setSize(width: width, height: height, animated: true)
        }
        .onChange(of: selectedAdvocateId) { _ in
            CommandPanelController.shared.setWidth(currentPanelWidth, animated: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: resolveRoundNotification)) { _ in
            guard let panelController else { return }
            guard CommandPanelController.shared === panelController else { return }
            triggerResolveRound()
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                                    .font(.system(size: 15, weight: .regular))
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
            HStack {
                Spacer()
                Text(problemTypeShortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(advocates) { advocate in
                Button {
                    toggleAdvocateSelection(advocate)
                } label: {
                    AdvocateCardView(
                        title: advocate.providerName,
                        summary: advocate.summary,
                        isSelected: selectedAdvocateId == advocate.id,
                        accentColor: shouldShowStanceColors ? (stanceColor(for: advocate.provider) ?? providerAccentColors[advocate.provider]) : nil,
                        isLoading: isResolveRoundInFlight
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, advocateTopPadding)
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
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                                    .font(.system(size: 15, weight: .regular))
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
            HStack {
                Spacer()
                Text(problemTypeShortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

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
                                isLoading: isResolveRoundInFlight
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, advocateTopPadding)
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
                triggerResolveRound()
            } label: {
                HStack(spacing: 6) {
                    Text("Resolve")

                    if canResolve && !isArbiterThinking {
                        ResolveKeycap("⌘ ⇧ R")
                    }
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .opacity(canResolve ? 1.0 : 0.45)
            .disabled(!canResolve)
        }
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(canSend ? 0.14 : 0.06))
            )
            .opacity(canSend ? 1.0 : 0.55)
            .disabled(!canSend)

            InlineCloseButton()
        }
        .opacity(inputContentOpacity)
        .offset(y: inputContentOffset)
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, phase != .loading else { return }

        lastSentText = trimmed
        submittedProblemType = problemType
        lastPromptTypeForBackend = promptTypeFor(problemType: problemType)

        withAnimation(.easeInOut(duration: 0.2)) {
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
            }

            do {
                let conversationId = try await ensureConversationId()
                let response = try await api.postMessage(
                    conversationId: conversationId,
                    content: trimmed,
                    promptType: lastPromptTypeForBackend,
                    summaryFormat: nil
                )

                await MainActor.run {
                    currentConversationId = conversationId
                    lastUserMessageId = response.message.id
                    arbiterSummaryText = response.run.arbiterOutput?.detailedResponse ?? "No response returned."
                    advocateResults = mapAdvocates(from: response.run)
                    classifierGroups = response.run.classifierOutput?.outputJson.groups ?? []
                    mcqDisagreement = response.run.mcqDisagreement
                    isArbiterThinking = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .responded
                    }
                    focused = true
                }
            } catch {
                await MainActor.run {
                    arbiterSummaryText = "Request failed: \(error.localizedDescription)"
                    isArbiterThinking = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .responded
                    }
                    focused = true
                }
            }
        }
    }

    private func performResolveRound() async {
        let (conversationId, messageId, promptType) = await MainActor.run {
            (currentConversationId, lastUserMessageId, lastPromptTypeForBackend)
        }

        guard let conversationId, let messageId else {
            await MainActor.run {
                arbiterSummaryText = "Nothing to resolve yet."
                isArbiterThinking = false
                isResolveRoundInFlight = false
            }
            return
        }

        do {
            let response = try await api.resolve(
                conversationId: conversationId,
                messageId: messageId,
                promptType: promptType,
                summaryFormat: nil
            )

            await MainActor.run {
                arbiterSummaryText = response.run.arbiterOutput?.detailedResponse ?? "No response returned."
                advocateResults = mapAdvocates(from: response.run)
                classifierGroups = response.run.classifierOutput?.outputJson.groups ?? []
                mcqDisagreement = response.run.mcqDisagreement
                isArbiterThinking = false
                isResolveRoundInFlight = false
            }
        } catch {
            await MainActor.run {
                arbiterSummaryText = "Request failed: \(error.localizedDescription)"
                isArbiterThinking = false
                isResolveRoundInFlight = false
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
                output = output + Text(value).bold()
            }
        }
        return output
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
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .composing
        }
        focused = true
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
            await MainActor.run {
                currentConversationId = conversationId
                classifierGroups = []
                mcqDisagreement = nil
                let lastUser = detail.messages.last(where: { $0.role.lowercased() == "user" })
                lastUserMessageId = lastUser?.id
                lastSentText = lastUser?.content ?? ""
                if let pt = lastUser?.promptType {
                    lastPromptTypeForBackend = pt
                }

                arbiterSummaryText = ""

                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = (lastUser != nil) ? .responded : .composing
                }
            }
        } catch {
            await MainActor.run {
                lastUserMessageId = nil
                classifierGroups = []
                mcqDisagreement = nil
                lastSentText = ""
                arbiterSummaryText = ""
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .composing
                }
            }
        }
    }

    func mapAdvocates(from run: RunResult) -> [AdvocateResult] {
        run.advocateOutputs.map { output in
            let provider = mapProvider(output.provider, advocateKey: output.advocateKey)

            let detailed = output.detailedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = output.summary.trimmingCharacters(in: .whitespacesAndNewlines)

            return AdvocateResult(
                provider: provider,
                explanation: detailed.isEmpty ? "No response." : detailed,
                summary: summary.isEmpty ? "Summary could not be parsed" : summary
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
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.35 : 0.10), lineWidth: 1)
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
                    .lineLimit(5)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(isSelected ? 0.35 : 0.10), lineWidth: 1)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.10 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
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
