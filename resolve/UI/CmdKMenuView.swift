import SwiftUI
import AppKit

/// One row in the ⌘K command menu. Built dynamically by `RootPanelView`
/// based on auth state, current route, and panel kind. Each action is
/// click- AND keyboard-fireable from inside the menu (Return picks the
/// currently-highlighted row).
struct CmdKAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let keys: String
    let action: () -> Void
}

/// Spotlight-style command menu surfaced via ⌘K. Renders as a standalone
/// floating window centered on the screen (see `CmdKWindowController`),
/// not as an overlay inside the Resolve panel — this keeps it visually
/// separate from whatever route the panel is currently on.
struct CmdKMenuView: View {
    let actions: [CmdKAction]
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var queryFocused: Bool

    @ObservedObject private var settings = UserSettingsStore.shared

    private var filteredActions: [CmdKAction] {
        guard !query.isEmpty else { return actions }
        let q = query.lowercased()
        return actions.filter { action in
            action.title.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            Divider()
                .overlay(Color.white.opacity(0.10))

            actionList
        }
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(settings.panelTranslucency.material)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 30, x: 0, y: 8)
        .overlay(
            // Hidden Esc handler — works whether or not the search field
            // currently has focus.
            Button("") { onDismiss() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
        .padding(20)
        .onAppear {
            queryFocused = true
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search actions…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($queryFocused)
                .onSubmit { fireSelected() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var actionList: some View {
        if filteredActions.isEmpty {
            Text("No actions match")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(filteredActions.enumerated()), id: \.element.id) { idx, action in
                        CmdKActionRow(
                            action: action,
                            isSelected: idx == selectedIndex
                        ) {
                            action.action()
                            onDismiss()
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 360)
        }
    }

    private func fireSelected() {
        guard !filteredActions.isEmpty else { return }
        let idx = max(0, min(selectedIndex, filteredActions.count - 1))
        let action = filteredActions[idx]
        action.action()
        onDismiss()
    }
}

private struct CmdKActionRow: View {
    let action: CmdKAction
    let isSelected: Bool
    let onClick: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(action.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if !action.keys.isEmpty {
                    Text(action.keys)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected || isHovering ? Color.white.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Owns the floating ⌘K window. The window is screen-centered (not
/// panel-centered) so it feels like a global command surface rather
/// than a sub-view of whichever Resolve panel was active. The window
/// is created lazily on first ⌘K and reused thereafter; `actions` is
/// recomputed and re-bound on every show.
@MainActor
final class CmdKWindowController: NSObject, NSWindowDelegate {
    static let shared = CmdKWindowController()

    private var panel: NSPanel?
    private var hostingController: NSHostingController<CmdKMenuView>?

    func toggle(actions: [CmdKAction]) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(actions: actions)
        }
    }

    func show(actions: [CmdKAction]) {
        createPanelIfNeeded()
        guard let panel, let hostingController else { return }

        // Rebuild the SwiftUI root every show so that `actions` reflects
        // the latest auth state / route at the moment ⌘K was pressed.
        hostingController.rootView = CmdKMenuView(actions: actions) { [weak self] in
            self?.hide()
        }

        // Size to fit the menu's intrinsic content (480pt wide card +
        // 20pt padding on each side; height capped by the scroll view).
        let size = hostingController.view.fittingSize
        let targetSize = NSSize(width: max(size.width, 520), height: max(size.height, 200))
        centerOnScreen(panel: panel, size: targetSize)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func centerOnScreen(panel: NSPanel, size: NSSize) {
        // Center on the screen the user is currently looking at — i.e.
        // the screen that owns the active Resolve panel if one exists,
        // otherwise the main screen.
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            panel.setContentSize(size)
            return
        }
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func createPanelIfNeeded() {
        guard panel == nil else { return }

        let host = NSHostingController(rootView: CmdKMenuView(actions: []) { })
        self.hostingController = host

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .modalPanel
        p.hasShadow = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.becomesKeyOnlyIfNeeded = false
        p.delegate = self
        p.contentView = host.view
        self.panel = p
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Click anywhere outside → dismiss, matching Spotlight/Raycast.
        hide()
    }
}
