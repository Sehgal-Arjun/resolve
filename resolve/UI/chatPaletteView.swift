import SwiftUI

struct ChatPaletteView: View {
    enum Phase {
        case composing
        case loading
        case responded
    }

    enum ProblemType: String, CaseIterable, Identifiable {
        case multipleChoiceSingle = "Multiple Choice – Single Select"
        case multipleChoiceMulti = "Multiple Choice – Multi Select"
        case generalQuestion = "General Question"
        case comparison = "Comparison"

        var id: String { rawValue }
    }

    @State private var text = ""
    @State private var phase: Phase = .composing
    @State private var responseText = ""
    @State private var lastSentText = ""
    @State private var problemType: ProblemType = .multipleChoiceSingle
    @State private var submittedProblemType: ProblemType = .multipleChoiceSingle
    @State private var selectedAdvocateId: String?
    @FocusState private var focused: Bool

    private let baseHeight: CGFloat = 140
    private let expandedHeight: CGFloat = 460
    private let baseWidth: CGFloat = 620
    private let expandedWidth: CGFloat = 760
    private let drawerWidth: CGFloat = 260
    private let useLiveAPI = false
    private let singleSelectAdvocateWidth: CGFloat = 150
    private let multiSelectAdvocateWidth: CGFloat = 170
    private let generalQuestionAdvocateWidth: CGFloat = 230
    private let advocateTopPadding: CGFloat = 44

    private var canSend: Bool {
        phase != .loading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDrawerOpen: Bool {
        selectedAdvocateId != nil
    }

    private var currentPanelWidth: CGFloat {
        let base = phase == .composing ? baseWidth : expandedWidth
        return isDrawerOpen && phase != .composing ? base + drawerWidth : base
    }

    private var inputContentOpacity: Double {
        phase == .loading ? 0.25 : 1.0
    }

    private var inputContentOffset: CGFloat {
        phase == .loading ? 10 : 0
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
                            .controlSize(.large)
                        Text("Resolving…")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .responded:
                    ScrollView {
                        Text(responseText)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
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
                        title: advocate.name,
                        value: advocateValue(for: advocate),
                        isSelected: selectedAdvocateId == advocate.id
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

    private var advocates: [AdvocateItem] {
        [
            AdvocateItem(
                id: "chatgpt",
                name: "ChatGPT",
                singleValue: "A",
                multiValue: "A, C, D",
                thesis: "Concise thesis summary placeholder text for the model answer.",
                reasoning: "Detailed reasoning placeholder for ChatGPT. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            ),
            AdvocateItem(
                id: "gemini",
                name: "Gemini",
                singleValue: "A",
                multiValue: "A, C, D",
                thesis: "Concise thesis summary placeholder text for the model answer.",
                reasoning: "Detailed reasoning placeholder for Gemini. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            ),
            AdvocateItem(
                id: "claude",
                name: "Claude",
                singleValue: "A",
                multiValue: "A, C, D",
                thesis: "Concise thesis summary placeholder text for the model answer.",
                reasoning: "Detailed reasoning placeholder for Claude. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            ),
            AdvocateItem(
                id: "grok",
                name: "Grok",
                singleValue: "A",
                multiValue: "A, C, D",
                thesis: "Concise thesis summary placeholder text for the model answer.",
                reasoning: "Detailed reasoning placeholder for Grok. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            ),
            AdvocateItem(
                id: "deepseek",
                name: "DeepSeek",
                singleValue: "B",
                multiValue: "B, D",
                thesis: "Concise thesis summary placeholder text for the model answer.",
                reasoning: "Detailed reasoning placeholder for DeepSeek. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            )
        ]
    }

    private var selectedAdvocate: AdvocateItem? {
        advocates.first { $0.id == selectedAdvocateId }
    }

    private func advocateValue(for advocate: AdvocateItem) -> String {
        switch submittedProblemType {
        case .multipleChoiceSingle:
            return advocate.singleValue
        case .multipleChoiceMulti:
            return advocate.multiValue
        case .generalQuestion, .comparison:
            return ""
        }
    }

    private func toggleAdvocateSelection(_ advocate: AdvocateItem) {
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

    private func advocateDrawer(for advocate: AdvocateItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(advocate.name)
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
                Text(advocate.reasoning)
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

            generalQuestionHeader

            ScrollView {
                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
            }
        }
    }

    private var generalQuestionHeader: some View {
        HStack(spacing: 8) {
            Text(submittedProblemType == .comparison ? "Recommendation" : "Answer")
                .font(.system(size: 13, weight: .semibold))

            Spacer()
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
                                title: advocate.name,
                                thesis: advocate.thesis,
                                isSelected: selectedAdvocateId == advocate.id
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
            if phase == .loading {
                ProgressView()
                    .controlSize(.small)
                Text("Resolving…")
                    .font(.system(size: 13, weight: .semibold))
            } else {
                Text("Answer")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
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
                responseText = ""
            }

            do {
                let reply = useLiveAPI
                    ? (try await fetchClaudeResponse(for: lastSentText))
                    : "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
                await MainActor.run {
                    responseText = reply
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .responded
                    }
                    focused = true
                }
            } catch {
                await MainActor.run {
                    responseText = "Request failed: \(error.localizedDescription)"
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .responded
                    }
                    focused = true
                }
            }
        }
    }

}

private extension ChatPaletteView {
    struct AdvocateItem: Identifiable {
        let id: String
        let name: String
        let singleValue: String
        let multiValue: String
        let thesis: String
        let reasoning: String
    }

    struct AdvocateCardView: View {
        let title: String
        let value: String
        let isSelected: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
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
        }
    }

    struct AdvocateThesisCardView: View {
        let title: String
        let thesis: String
        let isSelected: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(thesis)
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
        let apiKey = APIKeys.CLAUDE_ARBITER
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

#Preview {
    ZStack {
        Color.gray.opacity(0.2) // background to see bounds

        ChatPaletteView()
            .frame(width: 620, height: 420)
    }
    .frame(width: 1000, height: 600)
}

