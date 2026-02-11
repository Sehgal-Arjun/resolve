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
            }
        }
    }
}
