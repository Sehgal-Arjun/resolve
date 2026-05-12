import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePalette = Self("togglePalette")
    static let closeInstance = Self("closeInstance")
    static let diveIn = Self("diveIn")
    static let resolveRound = Self("resolveRound")
    static let newInstance = Self("newInstance")
    static let openSettings = Self("openSettings")
    static let focusOriginal = Self("focusOriginal")
    /// Global "Ask Resolve" — synthesizes ⌘C in the frontmost app to
    /// grab the selection, then dispatches the captured text into a
    /// fresh auto-sending Resolve chat. Same end behavior as the
    /// `Ask Resolve` Service entry under right-click → Services, just
    /// without making the user dive into the submenu.
    static let askResolve = Self("askResolve")
}

/// Display labels and default chords for every customizable shortcut. Drives
/// both the initial seeding in `AppController` and the rows in the Edit
/// Shortcuts page.
struct ShortcutSpec: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let name: KeyboardShortcuts.Name
}

/// Only the toggle-palette chord is exposed as a customizable global hotkey.
/// Every other shortcut (⌘N, ⌘⇧R, ⌘⇧N, ⌘W, ⌘,, ⌘⇧O) is a local SwiftUI
/// menu shortcut wired up in `resolveApp.commands` — those only fire when
/// Resolve is frontmost, so they don't intercept keystrokes from other apps.
let resolveCustomizableShortcuts: [ShortcutSpec] = [
    ShortcutSpec(id: "togglePalette", title: "Toggle palette",
                 subtitle: "Show/hide every Resolve panel from anywhere. The only Resolve shortcut that works system-wide.",
                 name: .togglePalette),
    ShortcutSpec(id: "askResolve", title: "Ask Resolve",
                 subtitle: "Take whatever's selected in the frontmost app and drop it into a new auto-sending Resolve chat.",
                 name: .askResolve)
]

let diveInNotification = NSNotification.Name("resolve.diveIn")
let resolveRoundNotification = NSNotification.Name("resolve.resolveRound")
let openSettingsNotification = NSNotification.Name("resolve.openSettings")
/// Posted whenever the toggle-palette shortcut (default ⌘ ;) fires. The
/// onboarding flow listens for this to detect the hide/show gesture.
let togglePaletteUsedNotification = NSNotification.Name("resolve.togglePaletteUsed")

// Chat-context shortcuts that the ⌘K command menu wants to surface. Each
// posts a notification rather than calling chat code directly, so the
// menu doesn't need a handle to the active chat view. `ChatPaletteView`
// listens for these and routes them to its existing handlers, gated on
// active-panel identity and current phase the same way `resolveRound`
// is.
let previousRoundNotification = NSNotification.Name("resolve.previousRound")
let nextRoundNotification = NSNotification.Name("resolve.nextRound")
let closeAdvocateDrawerNotification = NSNotification.Name("resolve.closeAdvocateDrawer")
let copyArbiterSummaryNotification = NSNotification.Name("resolve.copyArbiterSummary")
let exportChatMarkdownNotification = NSNotification.Name("resolve.exportChatMarkdown")

/// Posted by the macOS Service handler when the user invokes the
/// "Ask Resolve" entry from any app's right-click menu. The selected
/// text is delivered via `userInfo["text"]`. RootPanelView observes
/// this and routes the user into a new auto-sending chat.
let askResolveServiceNotification = NSNotification.Name("resolve.askResolveService")
