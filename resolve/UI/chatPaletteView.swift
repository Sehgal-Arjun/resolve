import SwiftUI

struct ChatPaletteView: View {
    enum Phase {
        case composing
        case loading
        case responded
    }

    @State private var text = ""
    @State private var phase: Phase = .composing
    @State private var responseText = ""
    @State private var lastSentText = ""
    @FocusState private var focused: Bool

    private let baseHeight: CGFloat = 140
    private let expandedHeight: CGFloat = 420
    private let useLiveAPI = false

    private var canSend: Bool {
        phase != .loading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        .frame(width: 620, height: phase == .composing ? baseHeight : expandedHeight)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }
        }
        .onChange(of: phase) { newPhase in
            let height = newPhase == .composing ? baseHeight : expandedHeight
            CommandPanelController.shared.setHeight(height, animated: true)
        }
    }

    private var topArea: some View {
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

            Text("5/6 models")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
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
    ChatPaletteView()
}
