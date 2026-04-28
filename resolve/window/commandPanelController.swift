import Cocoa
import SwiftUI

@MainActor
final class CommandPanelController: NSObject, NSWindowDelegate {
    static let primary = CommandPanelController(isPrimary: true)
    static var shared: CommandPanelController { activeController ?? primary }
    private static weak var activeController: CommandPanelController?

    let isPrimary: Bool

    private var panel: NSPanel?
    private var isShown = false
    private var savedFrame: NSRect?
    private var hasBeenPositioned = false

    var isVisible: Bool {
        panel?.isVisible == true
    }

    init(isPrimary: Bool) {
        self.isPrimary = isPrimary
        super.init()
        createPanelIfNeeded()
    }

    func toggle() {
        guard let panel else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func hide() {
        guard let panel else { return }
        guard panel.isVisible else { return }
        savedFrame = panel.frame
        if isPrimary {
            UserSettingsStore.shared.setPersistedPrimaryPanelFrame(panel.frame)
        }
        panel.orderOut(nil)
    }

    func show() {
        createPanelIfNeeded()
        guard let panel else { return }

        let anchor = UserSettingsStore.shared.panelAnchor

        switch anchor {
        case .center:
            // Re-snap to the anchor on every show, not just the first launch.
            position(panel)
            savedFrame = nil

        case .lastPosition:
            if let savedFrame {
                panel.setFrame(savedFrame, display: true)
                self.savedFrame = nil
            } else if !hasBeenPositioned {
                position(panel)
            }
            // Otherwise leave the panel where it was — orderOut preserves frame.
        }

        hasBeenPositioned = true

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Snaps the panel to the current anchor immediately (used when the user
    /// changes `panelAnchor` while panels are visible).
    func reapplyAnchor() {
        guard let panel, panel.isVisible else { return }
        let anchor = UserSettingsStore.shared.panelAnchor
        switch anchor {
        case .center:
            position(panel)
        case .lastPosition:
            // Nothing to do — panel stays where it currently is, which becomes
            // the "last position" going forward.
            break
        }
    }

    func closeInstance() {
        guard !isPrimary else { return }
        panel?.close()
    }

    /// Forces macOS to recompute the panel's window shadow from the current
    /// pixel mask. Needed when the SwiftUI corner radius changes — without this,
    /// the system keeps drawing the previous shadow outline.
    func invalidateShadow() {
        panel?.invalidateShadow()
    }

    func setHeight(_ height: CGFloat, animated: Bool) {
        guard let panel else { return }

        let currentFrame = panel.frame
        let delta = height - currentFrame.height
        guard abs(delta) > 0.5 else { return }

        var newFrame = currentFrame
        newFrame.origin.y -= delta
        newFrame.size.height = height

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }

    func setSize(width: CGFloat, height: CGFloat, animated: Bool) {
        guard let panel else { return }

        let currentFrame = panel.frame
        let deltaHeight = height - currentFrame.height
        let deltaWidth = width - currentFrame.width

        guard abs(deltaHeight) > 0.5 || abs(deltaWidth) > 0.5 else { return }

        var newFrame = currentFrame
        newFrame.origin.y -= deltaHeight
        newFrame.origin.x -= deltaWidth / 2
        newFrame.size.height = height
        newFrame.size.width = width

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }

    func setWidth(_ width: CGFloat, animated: Bool) {
        guard let panel else { return }

        let currentFrame = panel.frame
        let deltaWidth = width - currentFrame.width
        guard abs(deltaWidth) > 0.5 else { return }

        var newFrame = currentFrame
        newFrame.size.width = width

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }

    private func createPanelIfNeeded() {
        guard panel == nil else { return }

        let hostingController = NSHostingController(
            rootView: PanelChromeView(showClose: !isPrimary, onClose: { [weak self] in
                self?.closeInstance()
            }, controller: self) {
                RootPanelView(authManager: AuthManager.shared)
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 540),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        // Disable the macOS window shadow — it's biased downward and clashes
        // with the SwiftUI ambient stance glow which surrounds the whole panel.
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        panel.contentView = hostingController.view
        self.panel = panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let anchor = UserSettingsStore.shared.panelAnchor

        switch anchor {
        case .center:
            let x = frame.midX - panel.frame.width / 2
            let y = frame.maxY - panel.frame.height - 120
            panel.setFrameOrigin(NSPoint(x: x, y: y))

        case .lastPosition:
            // Only the primary panel persists its frame across launches; secondary
            // panels still get a sensible center default.
            if isPrimary, let stored = UserSettingsStore.shared.persistedPrimaryPanelFrame {
                panel.setFrame(stored, display: true)
            } else {
                let x = frame.midX - panel.frame.width / 2
                let y = frame.maxY - panel.frame.height - 120
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        CommandPanelController.activeController = self
    }

    func windowDidMove(_ notification: Notification) {
        guard isPrimary, let panel else { return }
        UserSettingsStore.shared.setPersistedPrimaryPanelFrame(panel.frame)
    }

    func windowWillClose(_ notification: Notification) {
        if isPrimary {
            return
        }
        CommandPanelManager.shared.removeInstance(self)
    }
}
