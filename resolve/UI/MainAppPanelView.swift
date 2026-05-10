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
            // Ensure the panel matches the chat palette immediately; ChatPaletteView will resize
            // further as its internal phase changes.
            CommandPanelController.shared.setSize(width: baseWidth, height: baseHeight, animated: !settings.reducedMotion)
        }
    }
}
