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
    }

    /// Apply the built-in defaults the *first* time we see each shortcut. Never
    /// overwrite — a user customization made via `KeyboardShortcuts.Recorder`
    /// would otherwise be reset on every launch.
    private func seedDefaultShortcuts() {
        if KeyboardShortcuts.getShortcut(for: .togglePalette) == nil {
            KeyboardShortcuts.setShortcut(.init(.semicolon, modifiers: [.command]), for: .togglePalette)
        }
        if KeyboardShortcuts.getShortcut(for: .diveIn) == nil {
            KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command]), for: .diveIn)
        }
        if KeyboardShortcuts.getShortcut(for: .resolveRound) == nil {
            KeyboardShortcuts.setShortcut(.init(.r, modifiers: [.command, .shift]), for: .resolveRound)
        }
        if KeyboardShortcuts.getShortcut(for: .newInstance) == nil {
            KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .newInstance)
        }
        if KeyboardShortcuts.getShortcut(for: .closeInstance) == nil {
            KeyboardShortcuts.setShortcut(.init(.w, modifiers: [.command]), for: .closeInstance)
        }
        if KeyboardShortcuts.getShortcut(for: .openSettings) == nil {
            KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command]), for: .openSettings)
        }
        if KeyboardShortcuts.getShortcut(for: .focusOriginal) == nil {
            KeyboardShortcuts.setShortcut(.init(.o, modifiers: [.command, .shift]), for: .focusOriginal)
        }
    }

    private func wireShortcutHandlers() {
        // ⌘; — smart toggle. If Resolve is the active app, hide every panel and
        // restore focus to whatever app was active before us. Otherwise, bring
        // Resolve to the front and show the panels.
        KeyboardShortcuts.onKeyUp(for: .togglePalette) {
            CommandPanelManager.shared.smartToggle()
        }

        KeyboardShortcuts.onKeyUp(for: .diveIn) {
            NotificationCenter.default.post(name: diveInNotification, object: nil)
        }

        KeyboardShortcuts.onKeyUp(for: .resolveRound) {
            NotificationCenter.default.post(name: resolveRoundNotification, object: nil)
        }

        KeyboardShortcuts.onKeyUp(for: .newInstance) {
            CommandPanelManager.shared.newInstance()
        }

        KeyboardShortcuts.onKeyUp(for: .closeInstance) {
            CommandPanelController.shared.closeInstance()
        }

        KeyboardShortcuts.onKeyUp(for: .openSettings) {
            // Settings only opens when the original (primary) instance is the
            // focused/active panel. Pressing on a secondary instance is a no-op.
            guard CommandPanelController.shared === CommandPanelController.primary else { return }
            NotificationCenter.default.post(name: openSettingsNotification, object: nil)
        }

        KeyboardShortcuts.onKeyUp(for: .focusOriginal) {
            CommandPanelController.primary.show()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
