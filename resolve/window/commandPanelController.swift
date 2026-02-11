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
        panel.orderOut(nil)
    }

    func show() {
        createPanelIfNeeded()
        guard let panel else { return }

        if let savedFrame = savedFrame {
            panel.setFrame(savedFrame, display: true)
            self.savedFrame = nil
        } else if !hasBeenPositioned {
            position(panel)
            hasBeenPositioned = true
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func closeInstance() {
        guard !isPrimary else { return }
        panel?.close()
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
            }) {
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
        panel.hasShadow = true
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
        let x = frame.midX - panel.frame.width / 2
        let y = frame.maxY - panel.frame.height - 120
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        CommandPanelController.activeController = self
    }

    func windowWillClose(_ notification: Notification) {
        if isPrimary {
            return
        }
        CommandPanelManager.shared.removeInstance(self)
    }
}
