import SwiftUI

struct ChatPaletteView: View {
    let onBack: (() -> Void)?

    enum Phase {
        case composing
        case loading
        case responded
    }

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    @State private var text = ""
    @State private var phase: Phase = .composing
    @State private var arbiterSummaryText = ""
    @State private var isArbiterThinking = false
    @State private var roundIndex: Int = 0
    @State private var isResolveRoundInFlight = false
    @State private var lastSentText = ""
    @State private var problemType: ProblemType = .multipleChoiceSingle
    @State private var submittedProblemType: ProblemType = .multipleChoiceSingle
    @State private var advocateResults: [AdvocateResult] = []
    @State private var stanceGroups: [StanceGroup] = []
    @State private var selectedAdvocateId: String?
    @FocusState private var focused: Bool

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
        stanceProviderColorMap(from: stanceGroups)
    }

    private var resolvesRemaining: Int {
        max(0, maxRounds - roundIndex)
    }

    private var resolvesRemainingText: String {
        "\(resolvesRemaining)/\(maxRounds) resolves remaining"
    }

    private var canResolve: Bool {
        stanceGroups.count > 1 && roundIndex < maxRounds && !isResolveRoundInFlight
    }

    private var inputContentOpacity: Double {
        phase == .loading ? 0.25 : 1.0
    }

    private var inputContentOffset: CGFloat {
        phase == .loading ? 10 : 0
    }
    
    private var phaseString: String {
        switch phase {
        case .composing: return "composing"
        case .loading: return "loading"
        case .responded: return "responded"
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
    }

    private var topArea: some View {
        Group {
            switch submittedProblemType {
            case .generalQuestion, .comparison:
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
                        accentColor: providerAccentColors[advocate.provider],
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
        case .generalQuestion, .comparison:
            return generalQuestionAdvocateWidth
        }
    }

    private var advocateOptions: [String]? {
        switch submittedProblemType {
        case .multipleChoiceSingle, .multipleChoiceMulti:
            return ["Option A", "Option B", "Option C", "Option D"]
        case .generalQuestion, .comparison:
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
        case .comparison:
            return "Comparison"
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
        case .comparison:
            return "arrow.left.arrow.right"
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
            }

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
                                accentColor: providerAccentColors[advocate.provider],
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
                guard canResolve else { return }
                guard !isArbiterThinking else { return }

                roundIndex += 1
                isArbiterThinking = true
                isResolveRoundInFlight = true
                arbiterSummaryText = ""

                Task {
                    await performResolveRound()
                }
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

            Button(action: {}) {
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

                Button {
                    problemType = .comparison
                } label: {
                    Label("Comparison", systemImage: "arrow.left.arrow.right")
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
                stanceGroups = []
            }

            let advocateTask = Task {
                await AdvocateClient.fetchAllAdvocates(
                    problemType: submittedProblemType,
                    question: lastSentText,
                    options: advocateOptions
                )
            }

            let results = await advocateTask.value
            await MainActor.run {
                advocateResults = results
                isArbiterThinking = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .responded
                }
                focused = true
            }

            let groups = await classifyStances(
                problemType: submittedProblemType,
                question: lastSentText,
                advocateResults: results
            )
            await MainActor.run {
                stanceGroups = groups
            }

            do {
                let summary = try await ArbiterClient.summarizeInitial(
                    stanceGroups: groups,
                    advocateResults: results
                )
                await MainActor.run {
                    arbiterSummaryText = summary
                    isArbiterThinking = false
                }
            } catch {
                await MainActor.run {
                    arbiterSummaryText = "Request failed: \(error.localizedDescription)"
                    isArbiterThinking = false
                }
            }
        }
    }

    private func performResolveRound() async {
        let (problemType, rawQuestion, previousResults, previousGroups) = await MainActor.run {
            (submittedProblemType, lastSentText, advocateResults, stanceGroups)
        }

        var questionForRound = rawQuestion
        var labeledOptions: [LabeledOption]? = nil

        if problemType == .multipleChoiceSingle || problemType == .multipleChoiceMulti {
            let labeled = await LabelerClient.labelMCQ(rawQuestion: rawQuestion)
            guard labeled.ok,
                  let stem = labeled.question_stem,
                  let options = labeled.options,
                  options.count >= 2,
                  options.count <= 26 else {
                let reason = labeled.reason ?? "Could not reliably detect multiple-choice options."
                await MainActor.run {
                    arbiterSummaryText = "Resolve round failed: \(reason)"
                    isArbiterThinking = false
                }
                return
            }

            questionForRound = stem
            labeledOptions = options
        }

        let newResults = await AdvocateClient.reconsiderAllAdvocates(
            problemType: problemType,
            question: questionForRound,
            labeledOptions: labeledOptions,
            previousResults: previousResults,
            stanceGroups: previousGroups
        )

        let newGroups = await classifyStances(
            problemType: problemType,
            question: rawQuestion,
            advocateResults: newResults
        )

        do {
            let changeSummary = try await ArbiterClient.summarizeChanges(
                previousGroups: previousGroups,
                previousResults: previousResults,
                newGroups: newGroups,
                newResults: newResults
            )

            await MainActor.run {
                advocateResults = newResults
                stanceGroups = newGroups
                arbiterSummaryText = changeSummary
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

    private func stanceProviderColorMap(from groups: [StanceGroup]) -> [AdvocateProvider: Color] {
        let palette: [Color] = [.blue, .purple, .orange, .teal, .pink]
        guard !groups.isEmpty else { return [:] }

        let sortedGroups = groups.sorted {
            if $0.members.count != $1.members.count {
                return $0.members.count > $1.members.count
            }
            return $0.stanceID < $1.stanceID
        }

        var map: [AdvocateProvider: Color] = [:]
        for (index, group) in sortedGroups.enumerated() {
            let color = palette[index % palette.count]
            for member in group.members {
                map[member] = color
            }
        }

        return map
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
        // Preferred format: <bold>...</bold>
        if input.contains("<bold>") {
            return parseTagBoldSegments(input, openTag: "<bold>", closeTag: "</bold>")
        }

        // Legacy formats (kept for backward compatibility): ***...*** or **...**
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
                // No closing tag: treat the rest literally, including the opening tag.
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

    struct AnthropicMessageRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let maxTokens: Int
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case messages
        }
    }

    struct AnthropicMessageResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }

        let content: [ContentBlock]
    }

    struct AnthropicErrorResponse: Decodable {
        struct ErrorDetail: Decodable {
            let type: String
            let message: String
        }

        let error: ErrorDetail
    }

    func fetchClaudeResponse(for prompt: String) async throws -> String {
        let apiKey = APIKeys.ARBITER
        guard !apiKey.isEmpty else {
            return "Missing API key. Add your Anthropic key in Config/APIKeys.swift."
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return "Invalid API URL."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "Anthropic-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = AnthropicMessageRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 1024,
            messages: [
                .init(role: "user", content: prompt)
            ]
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return "Request failed. No HTTP response."
        }

        guard httpResponse.statusCode == 200 else {
            if let decodedError = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
                return "Request failed (\(httpResponse.statusCode)): \(decodedError.error.message)"
            }

            let body = String(data: data, encoding: .utf8) ?? ""
            let trimmed = body.isEmpty ? "No response body." : body
            return "Request failed (\(httpResponse.statusCode)): \(trimmed)"
        }

        let decoded = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        let text = decoded.content.compactMap { $0.text }.joined()
        return text.isEmpty ? "No response returned." : text
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
        Color.gray.opacity(0.2) // background to see bounds

        ChatPaletteView()
            .frame(width: 620, height: 420)
    }
    .frame(width: 1000, height: 600)
}

