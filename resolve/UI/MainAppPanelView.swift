import SwiftUI

struct MainAppPanelView: View {
    let initialConversationId: UUID?
    let onBack: () -> Void

    @ObservedObject private var settings = UserSettingsStore.shared

    private var baseWidth: CGFloat { settings.scaled(620) }
    private var baseHeight: CGFloat { settings.scaled(140) }

    var body: some View {
        ChatPaletteView(initialConversationId: initialConversationId, onBack: onBack)
        .onAppear {
            // Ensure the panel matches the chat palette immediately; ChatPaletteView will resize
            // further as its internal phase changes.
            CommandPanelController.shared.setSize(width: baseWidth, height: baseHeight, animated: !settings.reducedMotion)
        }
    }
}
