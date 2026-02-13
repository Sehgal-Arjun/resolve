import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            print("AppDelegate open URL:", url.absoluteString)
            Task { await AuthManager.shared.handleClerkCallback(url: url) }
        }
    }
}
