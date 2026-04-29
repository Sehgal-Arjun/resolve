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
            // Menu items kept for discoverability. The actual hotkey bindings
            // are owned by `KeyboardShortcuts` (see `AppController`) so users
            // can customize them — that's why no `.keyboardShortcut` modifier
            // is set here (otherwise both systems would fire on the same chord).
            CommandGroup(after: .newItem) {
                Button("New Instance") {
                    CommandPanelManager.shared.newInstance()
                }

                Button("Resolve") {
                    NotificationCenter.default.post(name: resolveRoundNotification, object: nil)
                }

                Button("Close Instance") {
                    CommandPanelController.shared.closeInstance()
                }

                Button("Settings") {
                    guard CommandPanelController.shared === CommandPanelController.primary else { return }
                    NotificationCenter.default.post(name: openSettingsNotification, object: nil)
                }

                Button("Focus Original Instance") {
                    CommandPanelController.primary.show()
                }
            }
        }
    }
}
