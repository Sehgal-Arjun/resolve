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
