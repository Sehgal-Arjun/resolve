import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Touch the notifications singleton early so its
        // `UNUserNotificationCenter.delegate` registration runs
        // before any chat round can complete. Without this, the
        // first notification's `willPresent` falls back to default
        // suppression behavior.
        _ = ResolveNotifications.shared
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            print("AppDelegate open URL:", url.absoluteString)
            Task { await AuthManager.shared.handleClerkCallback(url: url) }
        }
    }

    /// Fires when the user clicks the Dock icon (or otherwise re-opens
    /// the app while it's already running). Surface the panel — same
    /// behavior as fresh launch: opening the app should show the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DispatchQueue.main.async {
            CommandPanelManager.shared.showAll()
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}
