import AppKit
import InputMethodKit

@objc(SmartInputController)
final class SmartInputController: IMKInputController {
    private let coordinator = CompositionCoordinator()
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool { coordinator.handle(event, client: sender) }
    override func commitComposition(_ sender: Any!) { coordinator.commitComposition(sender) }
    override func activateServer(_ sender: Any!) { coordinator.activateServer(sender) }
    override func deactivateServer(_ sender: Any!) { coordinator.deactivateServer(sender) }
    override func inputControllerWillClose() { coordinator.inputControllerWillClose() }
    override func hidePalettes() { coordinator.hidePalettes() }
    override func menu() -> NSMenu! { coordinator.menu() }
}
