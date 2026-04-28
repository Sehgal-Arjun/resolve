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

let resolveCustomizableShortcuts: [ShortcutSpec] = [
    ShortcutSpec(id: "togglePalette", title: "Toggle palette",
                 subtitle: "Show/hide every Resolve panel from anywhere.",
                 name: .togglePalette),
    ShortcutSpec(id: "diveIn", title: "Dive in",
                 subtitle: "Jump straight into a new chat from the home screen.",
                 name: .diveIn),
    ShortcutSpec(id: "resolveRound", title: "Resolve",
                 subtitle: "Trigger another resolve round on the current question.",
                 name: .resolveRound),
    ShortcutSpec(id: "newInstance", title: "New instance",
                 subtitle: "Open a brand-new Resolve panel.",
                 name: .newInstance),
    ShortcutSpec(id: "closeInstance", title: "Close instance",
                 subtitle: "Close the active secondary instance (no-op on the original).",
                 name: .closeInstance),
    ShortcutSpec(id: "openSettings", title: "Settings",
                 subtitle: "Open Settings (only when the original instance is focused).",
                 name: .openSettings),
    ShortcutSpec(id: "focusOriginal", title: "Focus original",
                 subtitle: "Bring the original instance forward.",
                 name: .focusOriginal)
]

let diveInNotification = NSNotification.Name("resolve.diveIn")
let resolveRoundNotification = NSNotification.Name("resolve.resolveRound")
let openSettingsNotification = NSNotification.Name("resolve.openSettings")
