import Foundation
import AppKit
import KeyboardShortcuts
import Combine

@MainActor
final class AppController: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    /// Token returned by `NSEvent.addLocalMonitorForEvents`. Held so the
    /// monitor stays alive for the lifetime of the controller (== the
    /// lifetime of the app).
    private var localKeyMonitor: Any?

    init() {
        seedDefaultShortcuts()
        wireShortcutHandlers()
        installLocalKeyMonitor()

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

        // Resolve is a menu-bar app with no Dock icon — without an
        // auto-show, a fresh launch leaves the user staring at just
        // the menu bar icon. Surface the panel on every launch; the
        // user can still hide it via ⌘ ; once they're done.
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
        if KeyboardShortcuts.getShortcut(for: .askResolve) == nil {
            KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.command, .shift]), for: .askResolve)
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

        // ⌘⇧A (default) — Ask Resolve. Synthesizes ⌘C in the
        // frontmost app to capture the current selection, restores
        // the previous clipboard, and dispatches the captured text
        // into a fresh auto-sending Resolve chat. Same end-result as
        // the right-click → Services → Ask Resolve entry, but
        // skipping the menu dive.
        KeyboardShortcuts.onKeyUp(for: .askResolve) {
            ResolveServicesProvider.grabSelectionAndDispatch()
        }

        // All other shortcuts are routed through `installLocalKeyMonitor`
        // — they only fire when Resolve has key focus (its panel is
        // active), so they don't trample on other apps' bindings.
    }

    /// LSUIElement apps have no system menu bar, so SwiftUI's `.commands`
    /// keyboard shortcuts never fire. We replace them with a single
    /// `NSEvent.addLocalMonitorForEvents` that intercepts ⌘N, ⌘W, ⌘⇧R,
    /// ⌘⇧N, ⌘,, and ⌘⇧O while Resolve is the frontmost app. Local
    /// monitor scope: keystrokes destined for OUR app only — keystrokes
    /// in other apps are completely untouched.
    private func installLocalKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalKeyEvent(event)
        }
    }

    private func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()

        if mods == .command {
            switch chars {
            case "n":
                NotificationCenter.default.post(name: diveInNotification, object: nil)
                return nil
            case "w":
                CommandPanelController.shared.closeInstance()
                return nil
            case ",":
                guard CommandPanelController.shared === CommandPanelController.primary else {
                    return event
                }
                NotificationCenter.default.post(name: openSettingsNotification, object: nil)
                return nil
            default:
                return event
            }
        }

        if mods == [.command, .shift] {
            switch chars {
            case "r":
                NotificationCenter.default.post(name: resolveRoundNotification, object: nil)
                return nil
            case "n":
                CommandPanelManager.shared.newInstance()
                return nil
            case "o":
                CommandPanelController.primary.show()
                NSApp.activate(ignoringOtherApps: true)
                return nil
            default:
                return event
            }
        }

        return event
    }
}
