import Foundation

/// Where a keyboard-shortcut entry surfaces in the UI. A single shortcut can
/// appear in multiple surfaces — e.g. ⌘N is documented on the home list, in
/// the onboarding cheat sheet, and as a fireable action in the ⌘K menu.
enum KeyboardShortcutSurface: Hashable {
    /// Documentation row in the home view's "Keyboard shortcuts" panel.
    case homeList
    /// Documentation row in the onboarding cheat-sheet step.
    case onboardingCheatSheet
    /// Selectable entry in the ⌘K command menu.
    case cmdKMenu
}

/// Visibility predicate for shortcuts that depend on which panel kind the
/// user is on (primary vs secondary instance, etc.). The catalog itself is
/// static; the predicate is evaluated by callers via `KeyboardShortcutContext`.
enum KeyboardShortcutAvailability {
    case always
    /// Only on the original/primary panel (e.g. Settings lives on the primary).
    case primaryOnly
    /// Only on secondary instances (e.g. "Focus original").
    case secondaryOnly
    /// Only when the current panel can be closed (i.e. is a secondary).
    case canCloseInstance
}

/// Runtime state used to filter the catalog. Constructed per call by the
/// surface that wants to render shortcuts; nothing in the catalog depends
/// on view state.
struct KeyboardShortcutContext {
    let isPrimaryPanel: Bool
    let canCloseInstance: Bool
}

/// One shortcut declared in Resolve. The catalog is the single source of
/// truth for the *display* of shortcuts (label, key glyphs, icon, where
/// they're surfaced). The actual `keyboardShortcut(...)` bindings still
/// live near the controls/views that fire them — so the catalog doesn't
/// drive behavior, just discoverability. A missing catalog entry can only
/// hide a shortcut from the lists; it can't break it.
struct KeyboardShortcut: Identifiable, Hashable {
    let id: String
    let label: String
    /// Display string like "⌘ ⇧ R". Used by the home list, the cheat
    /// sheet, and the ⌘K row.
    let keys: String
    /// SF Symbol name for the ⌘K menu row.
    let icon: String
    let surfaces: Set<KeyboardShortcutSurface>
    let availability: KeyboardShortcutAvailability

    func isAvailable(in context: KeyboardShortcutContext) -> Bool {
        switch availability {
        case .always: return true
        case .primaryOnly: return context.isPrimaryPanel
        case .secondaryOnly: return !context.isPrimaryPanel
        case .canCloseInstance: return context.canCloseInstance
        }
    }
}

enum KeyboardShortcutCatalog {
    static let all: [KeyboardShortcut] = [
        // -- Global / panel-level
        KeyboardShortcut(
            id: "togglePalette", label: "Toggle visibility", keys: "⌘ ;",
            icon: "sparkles",
            surfaces: [.homeList, .onboardingCheatSheet, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "newChat", label: "Get started / new chat", keys: "⌘ N",
            icon: "plus.bubble",
            surfaces: [.homeList, .onboardingCheatSheet, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "resolve", label: "Resolve", keys: "⌘ ⇧ R",
            icon: "wand.and.stars",
            surfaces: [.homeList, .onboardingCheatSheet, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "newInstance", label: "New instance", keys: "⌘ ⇧ N",
            icon: "rectangle.on.rectangle",
            surfaces: [.homeList, .onboardingCheatSheet, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "closeInstance", label: "Close instance", keys: "⌘ W",
            icon: "xmark.circle",
            surfaces: [.homeList, .cmdKMenu],
            availability: .canCloseInstance
        ),
        KeyboardShortcut(
            id: "settings", label: "Settings", keys: "⌘ ,",
            icon: "gearshape",
            surfaces: [.homeList, .onboardingCheatSheet, .cmdKMenu],
            availability: .primaryOnly
        ),
        KeyboardShortcut(
            id: "focusOriginal", label: "Focus original", keys: "⌘ ⇧ O",
            icon: "arrow.up.left.square",
            surfaces: [.homeList, .cmdKMenu],
            availability: .secondaryOnly
        ),

        // -- Navigation
        // Onboarding cheat sheet is intentionally curated to ~5 essentials
        // (matches the original list before the catalog existed) so it
        // fits the cheat-sheet panel without scrolling. The home list
        // scrolls and shows everything; ⌘K shows everything fireable.
        KeyboardShortcut(
            id: "openCommandMenu", label: "Open command menu", keys: "⌘ K",
            icon: "command",
            surfaces: [.homeList],
            availability: .always
        ),
        KeyboardShortcut(
            id: "back", label: "Go home", keys: "⌘ B",
            icon: "house",
            surfaces: [.homeList, .onboardingCheatSheet, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "howItWorks", label: "How Resolve Works", keys: "⌘ H",
            icon: "questionmark.circle",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "signOut", label: "Sign out", keys: "⌘ ⇧ S",
            icon: "rectangle.portrait.and.arrow.right",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),

        // -- Chat: send
        KeyboardShortcut(
            id: "sendChat", label: "Send chat", keys: "⌘ ↵",
            icon: "arrow.up.circle",
            surfaces: [.homeList],
            availability: .always
        ),

        // -- Past chats
        KeyboardShortcut(
            id: "searchPastChats", label: "Search past chats", keys: "⌘ F",
            icon: "magnifyingglass",
            surfaces: [.homeList],
            availability: .always
        ),
        KeyboardShortcut(
            id: "deletePastChat", label: "Delete past chat", keys: "⌘ ⌫",
            icon: "trash",
            surfaces: [.homeList],
            availability: .always
        ),

        // -- Chat: round navigation
        KeyboardShortcut(
            id: "previousRound", label: "Previous round", keys: "⌘ [",
            icon: "chevron.left.circle",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "nextRound", label: "Next round", keys: "⌘ ]",
            icon: "chevron.right.circle",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),

        // -- Chat: advocate drawer
        KeyboardShortcut(
            id: "openAdvocate", label: "Open advocate 1–5", keys: "⌘ 1–5",
            icon: "person.crop.rectangle.stack",
            surfaces: [.homeList],
            availability: .always
        ),
        KeyboardShortcut(
            id: "closeDrawer", label: "Close advocate drawer", keys: "⌘ esc",
            icon: "sidebar.right",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),

        // -- Chat: copy / export
        KeyboardShortcut(
            id: "copySummary", label: "Copy arbiter summary", keys: "⌘ ⇧ C",
            icon: "doc.on.doc",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),
        KeyboardShortcut(
            id: "exportChat", label: "Export chat as markdown", keys: "⌘ ⇧ E",
            icon: "square.and.arrow.up",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),

        // -- Appearance
        KeyboardShortcut(
            id: "cycleStanceGlow", label: "Cycle ambient stance glow", keys: "⌘ G",
            icon: "circle.dashed",
            surfaces: [.homeList, .cmdKMenu],
            availability: .always
        ),

        // -- App
        KeyboardShortcut(
            id: "quit", label: "Quit Resolve", keys: "⌘ Q",
            icon: "power",
            surfaces: [.cmdKMenu],
            availability: .always
        ),
    ]

    /// All shortcuts that should be rendered in the given surface, after
    /// availability filtering against the supplied context.
    static func shortcuts(
        for surface: KeyboardShortcutSurface,
        context: KeyboardShortcutContext
    ) -> [KeyboardShortcut] {
        all.filter { $0.surfaces.contains(surface) && $0.isAvailable(in: context) }
    }

    /// Looks up the display chord for a shortcut by id. Used at call sites
    /// that already own the action closure (e.g. ⌘K menu rows) and just
    /// need the keys glyph from the catalog.
    static func keys(forId id: String) -> String {
        all.first(where: { $0.id == id })?.keys ?? ""
    }

    /// Lookup the full entry by id — useful when a caller wants both the
    /// label and the keys (e.g. a ⌘K row whose title can come from the
    /// catalog rather than being hardcoded).
    static func entry(forId id: String) -> KeyboardShortcut? {
        all.first(where: { $0.id == id })
    }
}
