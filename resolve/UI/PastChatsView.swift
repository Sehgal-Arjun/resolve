import SwiftUI

struct PastChatsView: View {
    let onBack: () -> Void
    let onOpenConversation: (UUID) -> Void
    /// Called when the empty-state picker resolves a prompt — either
    /// from a pre-baked example or the custom text field. Forwards to
    /// the chat panel which auto-sends.
    let onStartChatWithPrompt: (String) -> Void

    private var cardWidth: CGFloat { settings.scaled(520) }
    private let cardCornerRadius: CGFloat = 16

    /// Suggested prompts surfaced in the empty state. Distinct from the
    /// onboarding demo questions so a returning empty user doesn't see
    /// the same prompts they already saw during the tour. Tone is
    /// intentionally fun and debate-worthy rather than work-focused.
    private static let examplePrompts: [String] = [
        "Are aliens real, and have they ever visited Earth?",
        "What's the strongest argument for or against free will?",
        "If you could only eat one cuisine for the rest of your life, what should it be?",
        "Is the book usually better than the movie?",
        "Is it better to live in a big city or a small town?"
    ]

    @State private var conversations: [Conversation] = []
    /// Starts true so the first render shows "Loading…" instead of
    /// flashing the empty state for a frame before `loadConversations`
    /// has had a chance to populate the list.
    @State private var isLoading = true
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

    /// Inline-rename state. Non-nil id → that row renders a TextField
    /// instead of the static title; `editingDraft` holds the in-flight
    /// edit; Return commits, Esc cancels.
    @State private var editingConversationId: UUID? = nil
    @State private var editingDraft: String = ""
    @FocusState private var editingFocused: Bool

    /// Empty-state picker reveal. Default false (collapsed: just the
    /// hero + CTA button); becomes true after the user clicks "Try
    /// with an example" to surface the suggestion cards + custom input.
    @State private var showExamplePicker = false
    @State private var customPrompt: String = ""
    @FocusState private var customPromptFocused: Bool

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
            emptyState
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

                    // Same picker the empty state uses, surfaced at
                    // the end of the list as an "out of questions"
                    // nudge. Tapping the button expands inline; the
                    // expanded view's tap targets route through
                    // `onStartChatWithPrompt` exactly like the empty
                    // state.
                    Group {
                        if showExamplePicker {
                            emptyStateExamples
                        } else {
                            outOfQuestionsButton
                        }
                    }
                    .padding(.top, 14)
                }
            }
        }
    }

    private var outOfQuestionsButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                showExamplePicker = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Out of questions? Try one of these.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        if editingConversationId == conversation.id {
            editingRow(conversation)
        } else {
            readOnlyRow(conversation)
        }
    }

    private func readOnlyRow(_ conversation: Conversation) -> some View {
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
                .padding(.trailing, 64) // reserve space for the rename + trash buttons
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

            HStack(spacing: 6) {
                Spacer()

                Button {
                    startEditing(conversation)
                } label: {
                    Image(systemName: "pencil")
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
                .opacity(isHovered ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .help("Rename")

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
                .opacity(isHovered ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .help("Delete chat (⌘ ⌫)")
            }
            .padding(.trailing, 8)
        }
        .onHover { hovering in
            if hovering {
                hoveredConversationId = conversation.id
            } else if hoveredConversationId == conversation.id {
                hoveredConversationId = nil
            }
        }
    }

    private func editingRow(_ conversation: Conversation) -> some View {
        editingRowContent(conversation)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(editingRowBackground)
            .overlay(editingRowBorder)
            .overlay(editingRowHiddenShortcuts(for: conversation))
    }

    private func editingRowContent(_ conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Title", text: $editingDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .focused($editingFocused)
                .onSubmit { commitRename(for: conversation) }
                .onAppear {
                    // Defer the focus flip a tick so the TextField is
                    // mounted by the time we ask for focus; without
                    // the dispatch the first character can sometimes
                    // get eaten on slower machines.
                    DispatchQueue.main.async { editingFocused = true }
                }

            Text("\(conversation.resolveCount) resolves · ⌘ ↵ to save · esc to cancel")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }

    private var editingRowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.08))
    }

    private var editingRowBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(settings.resolvedAccentColor.opacity(0.45), lineWidth: 1)
    }

    /// Hidden 0×0 buttons that capture Esc (cancel) and ⌘↵ (save) so
    /// the user can dismiss/commit without having to leave the
    /// keyboard. The TextField's `onSubmit` covers plain Return as
    /// well; this is the deliberate "save" path.
    private func editingRowHiddenShortcuts(for conversation: Conversation) -> some View {
        Group {
            Button("") { cancelEditing() }
                .keyboardShortcut(.cancelAction)

            Button("") { commitRename(for: conversation) }
                .keyboardShortcut(.return, modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func displayTitle(_ conversation: Conversation) -> String {
        let trimmed = conversation.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                emptyStateHero

                if showExamplePicker {
                    emptyStateExamples
                } else {
                    emptyStateRevealButton
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
        }
    }

    private var emptyStateHero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(settings.resolvedAccentColor.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(settings.resolvedAccentColor)
            }

            Text("No chats yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Resolve compares frontier AI models on the questions you actually care about.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
    }

    private var emptyStateRevealButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                showExamplePicker = true
            }
        } label: {
            Text("Try with an example")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var emptyStateExamples: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pick one to try, or write your own.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                ForEach(Self.examplePrompts, id: \.self) { prompt in
                    examplePromptRow(prompt)
                }
            }

            customPromptField
                .padding(.top, 4)
        }
    }

    private func examplePromptRow(_ prompt: String) -> some View {
        Button {
            onStartChatWithPrompt(prompt)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.up.right.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                Text(prompt)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customPromptField: some View {
        customPromptFieldRow
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(customPromptFieldBackground)
            .overlay(customPromptFieldBorder)
    }

    private var customPromptFieldRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)

            TextField("Or write your own…", text: $customPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .focused($customPromptFocused)
                .onSubmit { submitCustomPrompt() }

            customPromptSubmitButton
        }
    }

    private var customPromptSubmitButton: some View {
        Button {
            submitCustomPrompt()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(canSubmitCustomPrompt ? Color.primary : Color.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .background(customPromptSubmitButtonBackground)
        .disabled(!canSubmitCustomPrompt)
    }

    private var customPromptSubmitButtonBackground: some View {
        // Mirror the chat input bar's send-button opacity so the empty
        // state's submit arrow doesn't read as more prominent than the
        // real one in the chat panel.
        let accentOpacity: Double = settings.accentColorChoice == .mono ? 0.14 : 0.22
        let fill: Color = canSubmitCustomPrompt
            ? settings.resolvedAccentColor.opacity(accentOpacity)
            : Color.white.opacity(0.06)
        return RoundedRectangle(cornerRadius: 7, style: .continuous).fill(fill)
    }

    private var customPromptFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.06))
    }

    private var customPromptFieldBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.white.opacity(customPromptFocused ? 0.20 : 0.10), lineWidth: 1)
    }

    private var canSubmitCustomPrompt: Bool {
        !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitCustomPrompt() {
        let trimmed = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onStartChatWithPrompt(trimmed)
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
    // MARK: - Rename

    @MainActor
    private func startEditing(_ conversation: Conversation) {
        editingDraft = conversation.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        editingConversationId = conversation.id
    }

    @MainActor
    private func cancelEditing() {
        editingConversationId = nil
        editingDraft = ""
    }

    /// Commit the in-flight rename. Trims the draft, no-ops on empty
    /// or unchanged values, then optimistically updates the local row
    /// and fires `PATCH /conversations/{id}` in the background. On
    /// failure the original title is restored and an error surfaces.
    @MainActor
    private func commitRename(for conversation: Conversation) {
        let trimmed = editingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTitle = conversation.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmed.isEmpty || trimmed == currentTitle {
            cancelEditing()
            return
        }

        // Optimistic local update: synthesize a new Conversation with
        // the new title so the row reflects the rename immediately.
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx] = Conversation(
                id: conversation.id,
                title: trimmed,
                resolveCount: conversation.resolveCount,
                createdAt: conversation.createdAt,
                updatedAt: Date()
            )
        }
        cancelEditing()

        let originalConversation = conversation
        Task {
            do {
                let updated = try await api.updateConversation(id: originalConversation.id, title: trimmed)
                // Replace the optimistic placeholder with the
                // server-canonical row (real updated_at, server-side
                // trimming applied, etc.).
                await MainActor.run {
                    if let idx = conversations.firstIndex(where: { $0.id == updated.id }) {
                        conversations[idx] = updated
                    }
                }
            } catch {
                await MainActor.run {
                    if let idx = conversations.firstIndex(where: { $0.id == originalConversation.id }) {
                        conversations[idx] = originalConversation
                    }
                    lastError = "Failed to rename: \(error.localizedDescription)"
                }
                print("PastChatsView.commitRename failed — \(error.localizedDescription)")
            }
        }
    }

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
