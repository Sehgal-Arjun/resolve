import SwiftUI

@main
struct resolveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController()
    /// Observed so the menu bar dropdown can disable "New Chat" when the
    /// user is signed out. SwiftUI rebuilds the MenuBarExtra content
    /// whenever an `@Published` on AuthManager changes.
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        // Resolve is a menu-bar / agent app (LSUIElement = true). The only
        // Scene declared here is the menu bar icon + dropdown. The actual
        // panel UI lives in NSPanel (CommandPanelController), shown/hidden
        // independently via ⌘ ; or the menu items below.
        //
        // Note: with LSUIElement we lose the system menu bar entirely, so
        // SwiftUI's `.commands` shortcuts no longer fire. Panel-active
        // keyboard shortcuts (⌘N, ⌘W, ⌘⇧R, etc.) are now routed through
        // `NSEvent.addLocalMonitorForEvents` in `AppController`, which
        // only fires when Resolve has key focus — same locality semantics
        // as menu shortcuts had, just plumbed differently.
        MenuBarExtra("Resolve", systemImage: "sparkles") {
            Button("Show / Hide Resolve") {
                CommandPanelManager.shared.smartToggle()
            }
            .keyboardShortcut(";", modifiers: .command)

            Divider()

            Button("New Chat") {
                CommandPanelManager.shared.showAll()
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: diveInNotification, object: nil)
            }
            // Greyed out until the user is signed in — there's no chat
            // route to drop them into otherwise.
            .disabled(!authManager.isAuthenticated)

            Divider()

            Button("Quit Resolve") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
