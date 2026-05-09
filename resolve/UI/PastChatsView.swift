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

    @State private var searchQuery: String = ""
    @FocusState private var searchFocused: Bool

    /// Tracks which row the user's pointer is currently over. Drives
    /// (a) which row's trash button is visible and (b) which row ⌘⌫
    /// targets when no row is explicitly selected.
    @State private var hoveredConversationId: UUID? = nil

    /// Pending-delete state. Non-nil → confirmation modal is up.
    @State private var pendingDeletion: Conversation? = nil

    @ObservedObject private var settings = UserSettingsStore.shared

    private let api = BackendAPIClient()

    private var filteredConversations: [Conversation] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return conversations }
        return conversations.filter { conversation in
            (conversation.title ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            background
            content
            hiddenShortcuts

            if let pending = pendingDeletion {
                deleteConfirmationOverlay(for: pending)
                    .transition(.opacity)
            }
        }
        .onAppear {
            Task { await loadConversations() }
        }
    }

    // MARK: - Background

    private var background: some View {
        RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
            .fill(settings.panelTranslucency.material)
            .overlay(
                RoundedRectangle(cornerRadius: settings.cornerRadius(cardCornerRadius), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 14, x: 0, y: 0)
            .frame(width: cardWidth)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            searchField
            list
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(width: cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private var header: some View {
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
            .overlay(alignment: .top) {
                if settings.showKeyboardHintChips {
                    ResolveKeyHintChip("⌘ B")
                        .fixedSize()
                        .offset(y: -20)
                        .opacity(isBackButtonHovering ? 1 : 0)
                        .animation(.easeOut(duration: 0.12), value: isBackButtonHovering)
                        .allowsHitTesting(false)
                }
            }

            Text("Past chats")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)

            TextField("Search past chats", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .focused($searchFocused)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            } else if !searchFocused, settings.showKeyboardHintChips {
                // Subtle chord hint: only when the field is empty and
                // unfocused, so it never competes with the user's input
                // and disappears the moment they engage with it.
                Text("⌘ F")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(searchFocused ? 0.20 : 0.10), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: searchFocused)
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
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
        } else if filteredConversations.isEmpty {
            Text("No matches for \u{201C}\(searchQuery)\u{201D}")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(filteredConversations) { conversation in
                        conversationRow(conversation)
                    }
                }
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        let isHovered = hoveredConversationId == conversation.id
        return ZStack {
            Button {
                onOpenConversation(conversation.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle(conversation))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("\(conversation.resolveCount) resolves")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .padding(.trailing, 32) // reserve space for the trash button
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovered ? 0.18 : 0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack {
                Spacer()
                Button {
                    pendingDeletion = conversation
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .padding(.trailing, 8)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .help("Delete chat (⌘ ⌫)")
            }
        }
        .onHover { hovering in
            if hovering {
                hoveredConversationId = conversation.id
            } else if hoveredConversationId == conversation.id {
                hoveredConversationId = nil
            }
        }
    }

    private func displayTitle(_ conversation: Conversation) -> String {
        let trimmed = conversation.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    // MARK: - Hidden shortcuts

    private var hiddenShortcuts: some View {
        Group {
            // ⌘ F — focus the search field.
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)

            // ⌘ ⌫ — request deletion for the currently-hovered row.
            Button("") {
                guard let id = hoveredConversationId,
                      let conversation = conversations.first(where: { $0.id == id }) else { return }
                pendingDeletion = conversation
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(hoveredConversationId == nil)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: - Delete confirmation

    private func deleteConfirmationOverlay(for conversation: Conversation) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { pendingDeletion = nil }

            VStack(alignment: .leading, spacing: 14) {
                Text("Delete this chat?")
                    .font(.system(size: 16, weight: .semibold))

                Text("\u{201C}\(displayTitle(conversation))\u{201D} and every round it contains will be removed. This can't be undone.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    Button {
                        pendingDeletion = nil
                    } label: {
                        HStack(spacing: 6) {
                            Text("Cancel")
                            if settings.showKeyboardHintChips {
                                Text("esc")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .keyboardShortcut(.cancelAction)

                    Button {
                        confirmDelete(conversation)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Delete")
                            if settings.showKeyboardHintChips {
                                Text("⌘ ↵")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.85))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.red.opacity(0.85))
                    )
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(20)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(settings.panelTranslucency.material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 30, x: 0, y: 8)
        }
    }

    // MARK: - Loading & deleting

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

    /// Synchronously yanks the conversation from the list and dismisses
    /// the modal, then fires the DELETE in the background. Doing the
    /// UI update synchronously (instead of behind `Task { await ... }`)
    /// avoids a one-frame scheduling gap where the user could see the
    /// row briefly persist after confirming, or click delete twice.
    @MainActor
    private func confirmDelete(_ conversation: Conversation) {
        let originalIndex = conversations.firstIndex(where: { $0.id == conversation.id })
        conversations.removeAll { $0.id == conversation.id }
        pendingDeletion = nil

        Task {
            do {
                try await api.deleteConversation(id: conversation.id)
            } catch {
                await MainActor.run {
                    // Restore at the original position so the user sees
                    // a clear failure state and can try again.
                    if let originalIndex {
                        let safeIndex = min(originalIndex, conversations.count)
                        conversations.insert(conversation, at: safeIndex)
                    } else {
                        conversations.append(conversation)
                        conversations.sort { $0.updatedAt > $1.updatedAt }
                    }
                    lastError = "Failed to delete conversation: \(error.localizedDescription)"
                }
                print("PastChatsView.confirmDelete failed — \(error.localizedDescription)")
            }
        }
    }
}
