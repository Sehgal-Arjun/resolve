import Foundation
import AppKit

@MainActor
final class CommandPanelManager {
    static let shared = CommandPanelManager()

    private var instances: [CommandPanelController] = []
    /// The most recent non-Resolve app to gain focus. Captured continuously so
    /// `smartToggle()` can hand focus back when the user hides Resolve.
    private weak var previousApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?
    private var deactivateObserver: NSObjectProtocol?

    init() {
        observeFrontmostApp()
        observeAppDeactivation()
    }

    deinit {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        if let deactivateObserver {
            NotificationCenter.default.removeObserver(deactivateObserver)
        }
    }

    private var allControllers: [CommandPanelController] {
        [CommandPanelController.primary] + instances
    }

    private var anyVisible: Bool {
        allControllers.contains { $0.isVisible }
    }

    /// Public read-only counterpart of `anyVisible`. Used by code that
    /// needs to know whether Resolve is on-screen — e.g. background
    /// notifications that should only fire when the panel is hidden.
    var hasVisiblePanel: Bool { anyVisible }

    func toggleAll() {
        if anyVisible {
            hideAll()
        } else {
            showAll()
        }
    }

    /// Spotlight/Raycast-style toggle. Resolve's panel always floats on top.
    /// - Panel visible → hide every panel, return focus to the previous app.
    /// - Panel hidden  → activate Resolve and show the panels.
    /// Whether `hideOnFocusLoss` is on or off, the visible/hidden distinction
    /// is the only thing that matters to the user.
    func smartToggle() {
        if anyVisible {
            hideAll()
            previousApp?.activate(options: [])
        } else {
            NSApp.activate(ignoringOtherApps: true)
            showAll()
        }
    }

    func showAll() {
        for controller in allControllers {
            controller.show()
        }
    }

    func hideAll() {
        for controller in allControllers {
            controller.hide()
        }
    }

    func newInstance() {
        let controller = CommandPanelController(isPrimary: false)
        instances.append(controller)
        controller.show()
    }

    func removeInstance(_ controller: CommandPanelController) {
        instances.removeAll { $0 === controller }
    }

    func invalidateAllShadows() {
        for controller in allControllers {
            controller.invalidateShadow()
        }
    }

    func reapplyAnchorToAll() {
        for controller in allControllers {
            controller.reapplyAnchor()
        }
    }

    func applyHideOnFocusLossToAll(_ enabled: Bool) {
        for controller in allControllers {
            controller.applyHideOnFocusLoss(enabled)
        }
    }

    // MARK: - Previous-app tracking

    private func observeAppDeactivation() {
        deactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if UserSettingsStore.shared.hideOnFocusLoss {
                self.hideAll()
            }
        }
    }

    private func observeFrontmostApp() {
        let ourBundleID = Bundle.main.bundleIdentifier
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            // Only remember non-Resolve apps. When Resolve activates, the value
            // captured before this notification stays as `previousApp` and is
            // what we restore focus to on `smartToggle` hide.
            if app.bundleIdentifier != ourBundleID {
                self.previousApp = app
            }
        }
    }
}
