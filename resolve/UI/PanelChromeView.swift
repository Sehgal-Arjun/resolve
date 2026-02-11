import SwiftUI

private struct ResolveCanCloseInstanceKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var resolveCanCloseInstance: Bool {
        get { self[ResolveCanCloseInstanceKey.self] }
        set { self[ResolveCanCloseInstanceKey.self] = newValue }
    }
}

struct PanelChromeView<Content: View>: View {
    let showClose: Bool
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHoveringClose = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()
                .environment(\.resolveCanCloseInstance, showClose)

            if showClose {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isHoveringClose ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(isHoveringClose ? 0.10 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .onHover { hovering in
                    isHoveringClose = hovering
                }
                .animation(.easeOut(duration: 0.12), value: isHoveringClose)
                .padding(14)
            }
        }
    }
}
