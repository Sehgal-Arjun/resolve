import SwiftUI

struct AuthenticatedView: View {
    let user: AuthManager.ClerkUser
    let onDiveIn: () -> Void
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

    private let panelWidth: CGFloat = 520
    private let panelHeight: CGFloat = 380
    private let cardWidth: CGFloat = 520
    private let cardCornerRadius: CGFloat = 16

    @Environment(\.resolveCanCloseInstance) private var canCloseInstance
    @Environment(\.resolveCloseAction) private var closeAction

    @State private var isDiveHovering = false
    @State private var isCloseHovering = false
    @State private var showHowItWorks = false

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

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ResolveLogoMark()

                    Text("Welcome to Resolve, " + displayName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }

                Button("Get started") {
                    onDiveIn()
                }
                .buttonStyle(ResolvePrimaryButtonStyle(isHovering: isDiveHovering))
                .onHover { isDiveHovering = $0 }
                .keyboardShortcut(.defaultAction)

                HStack(spacing: 8) {
                    ResolveInlineLinkButton("Settings") {
                        onSettings()
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    ResolveInlineLinkButton("How does Resolve work?") {
                        showHowItWorks = true
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    ResolveInlineLinkButton("Sign Out") {
                        onSignOut()
                    }
                }

                keyboardShortcuts

                Text("Models active: ChatGPT · Claude · Gemini · DeepSeek · Mistral")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(22)
            .frame(width: cardWidth)

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
        .sheet(isPresented: $showHowItWorks) {
            HowResolveWorksView()
        }
        .onAppear {
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: true)
        }
    }

    private var keyboardShortcuts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard shortcuts")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                ShortcutRow(label: "Toggle visibility", keys: "⌘ ;")
                ShortcutRow(label: "New resolve", keys: "⌘ N")
                ShortcutRow(label: "Resolve", keys: "⌘ ⏎")
                ShortcutRow(label: "New Instance", keys: "⌘ ⇧ N")
                if canCloseInstance {
                    ShortcutRow(label: "Close instance", keys: "⌘ W")
                }
                ShortcutRow(label: "Settings", keys: "⌘ ,")
            }
        }
        .padding(.top, 4)
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

private struct HowResolveWorksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How Resolve works")
                .font(.system(size: 16, weight: .semibold))

            Text("Placeholder content. This will explain the workflow and key concepts.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 420, height: 220)
    }
}
