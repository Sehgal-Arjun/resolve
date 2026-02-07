import SwiftUI

@main
struct resolveApp: App {
    @StateObject private var appController = AppController()

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
