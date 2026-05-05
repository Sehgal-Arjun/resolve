import SwiftUI

struct PastChatsView: View {
    let onBack: () -> Void
    let onOpenConversation: (UUID) -> Void

    private var cardWidth: CGFloat { settings.scaled(520) }
    private let cardCornerRadius: CGFloat = 16

    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var isBackButtonHovering = false

    @ObservedObject private var settings = UserSettingsStore.shared

    private let api = BackendAPIClient()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
                .fill(settings.panelTranslucency.material)
                .overlay(
                    RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.30), radius: 14, x: 0, y: 0)
                .frame(width: cardWidth)

            VStack(alignment: .leading, spacing: 16) {
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

                    // Hover-only hint: opacity-gated so layout doesn't
                    // shift when the chip appears.
                    ResolveKeyHintChip("⌘ B")
                        .opacity(isBackButtonHovering ? 1 : 0)
                        .animation(.easeOut(duration: 0.12), value: isBackButtonHovering)

                    Text("Past chats")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 8)

                Group {
                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Loading…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    } else if let lastError {
                        Text(lastError)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if conversations.isEmpty {
                        Text("No past chats yet")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.tertiary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(conversations) { conversation in
                                    Button {
                                        onOpenConversation(conversation.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(conversation.title?.isEmpty == false ? (conversation.title ?? "") : "Untitled")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.primary)

                                            Text("\(conversation.resolveCount) resolves")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(width: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        }
        .onAppear {
            Task { await loadConversations() }
        }
    }

    @MainActor
    private func loadConversations() async {
        isLoading = true
        lastError = nil
        do {
            let list = try await api.listConversations()
            conversations = list.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            lastError = "Failed to load conversations: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
