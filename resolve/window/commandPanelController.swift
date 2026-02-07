import Cocoa
import SwiftUI

@MainActor
final class CommandPanelController {
    static let shared = CommandPanelController()

    private var panel: NSPanel?
    private var isShown = false

    private init() {
        createPanelIfNeeded()
    }

    func toggle() {
        guard let panel else { return }

        if isShown {
            panel.orderOut(nil)
        } else {
            position(panel)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        isShown.toggle()
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
            rootView: ChatPaletteView()
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 140),
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
}
