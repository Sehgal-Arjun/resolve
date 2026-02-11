import Foundation
import AppKit
import KeyboardShortcuts
import Combine

@MainActor
final class AppController: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init() {
        AuthManager.shared.configureIfNeeded()

        KeyboardShortcuts.setShortcut(
            .init(.semicolon, modifiers: [.command]),
            for: .togglePalette
        )

        KeyboardShortcuts.onKeyUp(for: .togglePalette) {
            CommandPanelManager.shared.toggleAll()
        }

        AuthManager.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { state in
                switch state {
                case .signedIn(let user):
                    // Single-panel model: RootPanelView swaps content based on auth state.
                    // No extra panel should be created here.
                    _ = user
                case .signedOut, .signingIn, .signUpNeedsDetails, .signUpNeedsPhoneCode:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
