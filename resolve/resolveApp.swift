import SwiftUI

@main
struct resolveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController()

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Instance") {
                    CommandPanelManager.shared.newInstance()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Resolve") {
                    NotificationCenter.default.post(name: resolveRoundNotification, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Close Instance") {
                    CommandPanelController.shared.closeInstance()
                }
                .keyboardShortcut("w", modifiers: [.command])

                Button("Settings") {
                    // Settings only opens when the original (primary) instance is
                    // the focused/active panel. Pressing ⌘, on a secondary
                    // instance is a no-op — users use ⌘⇧O to focus the original
                    // first.
                    guard CommandPanelController.shared === CommandPanelController.primary else { return }
                    NotificationCenter.default.post(name: openSettingsNotification, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])

                Button("Focus Original Instance") {
                    CommandPanelController.primary.show()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
