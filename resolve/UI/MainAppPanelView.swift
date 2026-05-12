import SwiftUI

struct MainAppPanelView: View {
    let initialConversationId: UUID?
    let initialPrompt: String?
    let onBack: () -> Void

    @ObservedObject private var settings = UserSettingsStore.shared

    private var baseWidth: CGFloat { settings.scaled(620) }
    private var baseHeight: CGFloat { settings.scaled(140) }

    init(initialConversationId: UUID? = nil, initialPrompt: String? = nil, onBack: @escaping () -> Void) {
        self.initialConversationId = initialConversationId
        self.initialPrompt = initialPrompt
        self.onBack = onBack
    }

    var body: some View {
        ChatPaletteView(
            initialConversationId: initialConversationId,
            initialPrompt: initialPrompt,
            onBack: onBack
        )
        .onAppear {
            // Skip this initial composing-size resize when we're
            // about to auto-send: the chat jumps straight to the
            // expanded responded layout, and `ChatPaletteView`'s
            // onAppear handles sizing itself in that case. Without
            // this skip the panel would briefly snap to 140pt before
            // growing back to 460pt — a visible flicker that drags
            // the panel's center off the user's chosen position.
            guard initialPrompt == nil else { return }
            CommandPanelController.shared.setSize(width: baseWidth, height: baseHeight, animated: !settings.reducedMotion)
        }
    }
}
