import SwiftUI

struct ResolveLogoMark: View {
    var size: CGFloat = 28

    /// Corner radius and glyph size scale proportionally so the mark looks
    /// right at any size. At the default 28pt these resolve to ~9pt corner /
    /// ~13pt glyph (visually identical to the previous fixed values).
    private var cornerRadius: CGFloat { size * 0.32 }
    private var glyphSize: CGFloat { size * 0.46 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

            Text("R")
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Resolve")
    }
}

struct ResolvePrimaryButtonStyle: ButtonStyle {
    var isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundFill(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderStroke(isPressed: configuration.isPressed), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func backgroundFill(isPressed: Bool) -> Color {
        if isPressed { return Color.white.opacity(0.08) }
        return Color.white.opacity(isHovering ? 0.14 : 0.12)
    }

    private func borderStroke(isPressed: Bool) -> Color {
        if isPressed { return Color.white.opacity(0.14) }
        return Color.white.opacity(isHovering ? 0.18 : 0.14)
    }
}

struct ResolveInlineLinkButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovering = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title) {
            action()
        }
        .buttonStyle(.plain)
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(isHovering ? .primary : .secondary)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

/// Small monospaced "⌘ B"-style chip that appears next to a button or
/// control to advertise its keyboard shortcut. Renders nothing when the
/// user has turned off `showKeyboardHintChips` in Settings.
struct ResolveKeyHintChip: View {
    let keys: String

    @ObservedObject private var settings = UserSettingsStore.shared

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        if settings.showKeyboardHintChips {
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}
