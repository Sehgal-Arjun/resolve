import SwiftUI

struct PastChatsView: View {
    let onBack: () -> Void
    let onOpenConversation: (UUID) -> Void

    private let cardWidth: CGFloat = 520
    private let cardCornerRadius: CGFloat = 16

    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var lastError: String?

    private let api = BackendAPIClient()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(radius: 16)
                .frame(width: cardWidth)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

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
