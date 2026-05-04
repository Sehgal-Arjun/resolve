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
            // Local-only menu shortcuts: each `.keyboardShortcut` here is
            // active only when Resolve is the frontmost app. Other apps'
            // bindings (Chrome's ⌘W, Mail's ⌘N, etc.) are untouched. The
            // ONE exception is ⌘; — that's a true global hotkey wired up
            // through `KeyboardShortcuts` in `AppController`, so the user
            // can summon Resolve from anywhere.
            CommandGroup(after: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: diveInNotification, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Resolve") {
                    NotificationCenter.default.post(name: resolveRoundNotification, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("New Instance") {
                    CommandPanelManager.shared.newInstance()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Close Instance") {
                    CommandPanelController.shared.closeInstance()
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Settings") {
                    guard CommandPanelController.shared === CommandPanelController.primary else { return }
                    NotificationCenter.default.post(name: openSettingsNotification, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Focus Original Instance") {
                    CommandPanelController.primary.show()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
