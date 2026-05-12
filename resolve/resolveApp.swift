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

            // Reads the current pasteboard contents and dispatches
            // them into a new auto-sending chat. Same plumbing as the
            // ⌘⇧A global shortcut and the right-click Service entry,
            // but uses *what's already on the clipboard* instead of
            // synthesizing ⌘C — clicking a menu bar item moves focus
            // away from the source app, so the selection's gone by
            // the time we'd try to copy it.
            Button("Ask Resolve") {
                let raw = NSPasteboard.general.string(forType: .string) ?? ""
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    ResolveServicesProvider.dispatch(text: trimmed)
                } else {
                    // Empty clipboard — fall through to the new-chat
                    // experience so the user can type something.
                    CommandPanelManager.shared.showAll()
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: diveInNotification, object: nil)
                }
            }
            // Just renders the chord glyph next to the menu item.
            // The real global binding is registered via the
            // KeyboardShortcuts package in `AppController`, so this
            // declaration doesn't actually capture the chord — it's
            // purely visual. Same pattern as the Show/Hide row above.
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(!authManager.isAuthenticated)

            Divider()

            Button("Quit Resolve") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
