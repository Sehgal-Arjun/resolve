import SwiftUI

private struct ResolveCanCloseInstanceKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct ResolveCloseActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct ResolveChatPhaseKey: EnvironmentKey {
    static let defaultValue: String = "other"
}

extension EnvironmentValues {
    var resolveCanCloseInstance: Bool {
        get { self[ResolveCanCloseInstanceKey.self] }
        set { self[ResolveCanCloseInstanceKey.self] = newValue }
    }
    
    var resolveCloseAction: (() -> Void)? {
        get { self[ResolveCloseActionKey.self] }
        set { self[ResolveCloseActionKey.self] = newValue }
    }
    
    var resolveChatPhase: String {
        get { self[ResolveChatPhaseKey.self] }
        set { self[ResolveChatPhaseKey.self] = newValue }
    }
}

struct PanelChromeView<Content: View>: View {
    let showClose: Bool
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHoveringClose = false

    private let closeInset: CGFloat = 28
    
    @Environment(\.resolveChatPhase) private var chatPhase

    var body: some View {
        content()
            .environment(\.resolveCanCloseInstance, showClose)
            .environment(\.resolveCloseAction, showClose ? onClose : nil)
    }
}
