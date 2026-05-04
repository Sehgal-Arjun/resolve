import Foundation
import AppKit
import KeyboardShortcuts
import Combine

@MainActor
final class AppController: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init() {
        seedDefaultShortcuts()
        wireShortcutHandlers()

        AuthManager.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { state in
                switch state {
                case .signedIn(let user):
                    // Single-panel model: RootPanelView swaps content based on auth state.
                    // No extra panel should be created here.
                    _ = user
                case .signedOut, .signingIn:
                    break
                }
            }
            .store(in: &cancellables)

        // Resolve is a panel-only app — without an auto-show, a fresh
        // launch leaves the user staring at just the Dock icon. Show
        // the panel on every launch (matches typical app behavior of
        // surfacing a window when opened). The user can still hide it
        // via ⌘ ; once they're done.
        DispatchQueue.main.async {
            CommandPanelManager.shared.showAll()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Only ⌘; is a true global hotkey. Everything else is a SwiftUI menu
    /// shortcut wired up in `resolveApp.commands` — those only fire when
    /// Resolve is the active app, so ⌘W in Chrome closes a Chrome tab,
    /// ⌘N in Mail composes a Mail message, etc.
    ///
    /// We also explicitly clear any non-⌘; entries that older builds might
    /// have registered. `KeyboardShortcuts.setShortcut(nil, for:)` removes
    /// the system-wide Carbon hotkey registration, releasing the keystroke
    /// back to whatever app is frontmost.
    private func seedDefaultShortcuts() {
        if KeyboardShortcuts.getShortcut(for: .togglePalette) == nil {
            KeyboardShortcuts.setShortcut(.init(.semicolon, modifiers: [.command]), for: .togglePalette)
        }
        KeyboardShortcuts.setShortcut(nil, for: .diveIn)
        KeyboardShortcuts.setShortcut(nil, for: .resolveRound)
        KeyboardShortcuts.setShortcut(nil, for: .newInstance)
        KeyboardShortcuts.setShortcut(nil, for: .closeInstance)
        KeyboardShortcuts.setShortcut(nil, for: .openSettings)
        KeyboardShortcuts.setShortcut(nil, for: .focusOriginal)
    }

    private func wireShortcutHandlers() {
        // ⌘; — smart toggle. If Resolve is the active app, hide every panel and
        // restore focus to whatever app was active before us. Otherwise, bring
        // Resolve to the front and show the panels. Intentionally global —
        // this is the *only* shortcut Resolve needs to consume system-wide.
        KeyboardShortcuts.onKeyUp(for: .togglePalette) {
            CommandPanelManager.shared.smartToggle()
            NotificationCenter.default.post(name: togglePaletteUsedNotification, object: nil)
        }

        // All other shortcuts are SwiftUI menu shortcuts (resolveApp.commands).
        // They only fire when Resolve has focus, so they don't trample on
        // other apps' bindings.
    }
}
