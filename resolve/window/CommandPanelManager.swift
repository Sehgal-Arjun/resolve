import Foundation

@MainActor
final class CommandPanelManager {
    static let shared = CommandPanelManager()

    private var instances: [CommandPanelController] = []

    private var allControllers: [CommandPanelController] {
        [CommandPanelController.primary] + instances
    }

    private var anyVisible: Bool {
        allControllers.contains { $0.isVisible }
    }

    func toggleAll() {
        if anyVisible {
            hideAll()
        } else {
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
}
