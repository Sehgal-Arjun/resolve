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
                 name: .togglePalette)
]

let diveInNotification = NSNotification.Name("resolve.diveIn")
let resolveRoundNotification = NSNotification.Name("resolve.resolveRound")
let openSettingsNotification = NSNotification.Name("resolve.openSettings")
/// Posted whenever the toggle-palette shortcut (default ⌘ ;) fires. The
/// onboarding flow listens for this to detect the hide/show gesture.
let togglePaletteUsedNotification = NSNotification.Name("resolve.togglePaletteUsed")
