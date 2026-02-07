import Foundation
import KeyboardShortcuts

@MainActor
final class AppController: ObservableObject {

    init() {
        KeyboardShortcuts.setShortcut(
            .init(.semicolon, modifiers: [.command]),
            for: .togglePalette
        )

        KeyboardShortcuts.onKeyUp(for: .togglePalette) {
            CommandPanelController.shared.toggle()
        }
    }
}
