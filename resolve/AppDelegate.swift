import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Strong reference to the macOS Service handler. AppKit only
    /// keeps a weak reference via `NSApp.servicesProvider`, so we have
    /// to retain it here or the "Ask Resolve" service stops working
    /// shortly after launch.
    private let servicesProvider = ResolveServicesProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Touch the notifications singleton early so its
        // `UNUserNotificationCenter.delegate` registration runs
        // before any chat round can complete. Without this, the
        // first notification's `willPresent` falls back to default
        // suppression behavior.
        _ = ResolveNotifications.shared

        // Register the macOS Service handler so users can right-click
        // selected text in any app and pick "Ask Resolve". The system
        // routes the selection through `ResolveServicesProvider`
        // which posts an `askResolveServiceNotification` for
        // RootPanelView to consume. `NSUpdateDynamicServices()` tells
        // the system to refresh its cached services list — without
        // it, the menu item won't appear until the next reboot.
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()
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
