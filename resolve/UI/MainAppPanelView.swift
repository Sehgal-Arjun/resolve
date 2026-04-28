import SwiftUI

struct MainAppPanelView: View {
    let initialConversationId: UUID?
    let onBack: () -> Void

    private let baseWidth: CGFloat = 620
    private let baseHeight: CGFloat = 140

    var body: some View {
        ChatPaletteView(initialConversationId: initialConversationId, onBack: onBack)
        .onAppear {
            // Ensure the panel matches the chat palette immediately; ChatPaletteView will resize
            // further as its internal phase changes.
            CommandPanelController.shared.setSize(width: baseWidth, height: baseHeight, animated: true)
        }
    }
}
