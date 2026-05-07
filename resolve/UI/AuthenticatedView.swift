import SwiftUI

struct AuthenticatedView: View {
    let user: AuthManager.ClerkUser
    let isPrimary: Bool
    let onDiveIn: () -> Void
    let onPastChats: () -> Void
    let onHowItWorks: () -> Void
    let onSettings: () -> Void
    let onSignOut: () -> Void

    private var displayName: String {
        let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Signed in" }
        if let first = trimmed.split(separator: " ").first {
            return String(first)
        }
        return trimmed
    }

    private var panelWidth: CGFloat { settings.scaled(520) }
    private var panelHeight: CGFloat { settings.scaled(410) }
    private var cardWidth: CGFloat { settings.scaled(520) }
    private let cardCornerRadius: CGFloat = 16

    @Environment(\.resolveCanCloseInstance) private var canCloseInstance
    @Environment(\.resolveCloseAction) private var closeAction

    @ObservedObject private var settings = UserSettingsStore.shared

    @State private var isDiveHovering = false
    @State private var isCloseHovering = false

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

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ResolveLogoMark()

                    Text("Welcome to Resolve, " + displayName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }

                Button {
                    onDiveIn()
                } label: {
                    HStack(spacing: 10) {
                        Text("Get started")

                        Spacer(minLength: 0)

                        Keycap("⌘ N")
                    }
                }
                .buttonStyle(ResolvePrimaryButtonStyle(isHovering: isDiveHovering))
                .onHover { isDiveHovering = $0 }
                .keyboardShortcut(.defaultAction)

                HStack(spacing: 8) {
                    ResolveInlineLinkButton("Past chats") {
                        onPastChats()
                    }

                    if isPrimary {
                        Text("·")
                            .foregroundStyle(.tertiary)

                        ResolveInlineLinkButton("Settings") {
                            onSettings()
                        }
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    ResolveInlineLinkButton("How does Resolve work?", keyHint: "⌘ H") {
                        onHowItWorks()
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    ResolveInlineLinkButton("Sign Out", keyHint: "⌘ ⇧ S") {
                        onSignOut()
                    }
                }

                // Keyboard shortcuts list grows to fill the panel's
                // remaining vertical slack (where the trailing Spacer
                // used to sit). Long catalog → bottom row gets clipped
                // by the viewport edge, signalling the user to scroll.
                keyboardShortcuts

                if !isPrimary {
                    Text("Settings only lives on the original instance. Press ⌘ ⇧ O to focus it.")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(22)
            .frame(width: cardWidth, height: panelHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))

            if canCloseInstance, let closeAction {
                VStack {
                    HStack {
                        Spacer()

                        Button(action: closeAction) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isCloseHovering ? .primary : .secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(isCloseHovering ? 0.10 : 0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .onHover { hovering in
                            isCloseHovering = hovering
                        }
                        .animation(.easeOut(duration: 0.12), value: isCloseHovering)
                        .padding(14)
                    }

                    Spacer()
                }
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .onAppear {
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: !settings.reducedMotion)
        }
        .onChange(of: settings.panelSize) { _ in
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: !settings.reducedMotion)
        }
    }

    private var keyboardShortcuts: some View {
        // Source-of-truth list lives in `hotkeys/KeyboardShortcuts.swift`.
        let context = KeyboardShortcutContext(
            isPrimaryPanel: isPrimary,
            canCloseInstance: canCloseInstance
        )
        let entries = KeyboardShortcutCatalog.shortcuts(for: .homeList, context: context)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard shortcuts")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)

            // Fills the vertical slack the panel already has below this
            // section (the parent VStack's Spacer was eating it). When
            // the catalog overflows, the bottom row gets clipped by the
            // viewport edge — that visible cut is the scroll cue.
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        ShortcutRow(label: entry.label, keys: entry.keys)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 4)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct ShortcutRow: View {
    let label: String
    let keys: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Keycap(keys)
        }
    }
}

private struct Keycap: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06)) 
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

