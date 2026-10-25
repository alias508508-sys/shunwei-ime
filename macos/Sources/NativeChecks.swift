import AppKit
import InputMethodKit
import Carbon

// A controlled protocol client exercises the composition coordinator without changing the user's input sources.
final class CheckClient: NSObject, IMKTextInput {
    var text = ""
    var selection = NSRange(location: 0, length: 0)
    var marked = NSRange(location: NSNotFound, length: 0)
    func insertText(_ string: Any!, replacementRange: NSRange) {
        let value = (string as? String) ?? ""
        let range = replacementRange.location != NSNotFound ? replacementRange : marked.location != NSNotFound ? marked : selection
        text = (text as NSString).replacingCharacters(in: range, with: value)
        selection = NSRange(location: range.location + (value as NSString).length, length: 0)
        marked = NSRange(location: NSNotFound, length: 0)
    }
    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
        let value = (string as? String) ?? ""
        let range = replacementRange.location != NSNotFound ? replacementRange : marked.location != NSNotFound ? marked : selection
        text = (text as NSString).replacingCharacters(in: range, with: value)
        marked = NSRange(location: range.location, length: (value as NSString).length)
        selection = NSRange(location: range.location + selectionRange.location, length: selectionRange.length)
        if value.isEmpty { marked = NSRange(location: NSNotFound, length: 0) }
    }
    func selectedRange() -> NSRange { selection }
    func markedRange() -> NSRange { marked }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! {
        guard range.location != NSNotFound, NSMaxRange(range) <= (text as NSString).length else { return nil }
        return NSAttributedString(string: (text as NSString).substring(with: range))
    }
    func length() -> Int { (text as NSString).length }
    func characterIndex(for point: NSPoint, tracking mappingMode: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int { NSNotFound }
    func attributes(forCharacterIndex index: Int, lineHeightRectangle: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! { lineHeightRectangle?.pointee = .zero; return [:] }
    func validAttributesForMarkedText() -> [Any]! { [] }
    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}
    func selectMode(_ modeIdentifier: String!) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String! { "org.shunwrite.check-client" }
    func windowLevel() -> Int32 { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }
    func uniqueClientIdentifierString() -> String! { "check-client" }
    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! { actualRange?.pointee = range; return attributedSubstring(from: range)?.string }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer!) -> NSRect { actualRange?.pointee = range; return .zero }
}

func nativeChecks() {
    let client = CheckClient()
    let controller = CompositionCoordinator()
    var passed = 0
    func check(_ condition: Bool, _ name: String) { if !condition { fputs("FAILED: \(name) text=\(client.text)\n", stderr); exit(1) }; passed += 1 }
    @discardableResult func key(_ characters: String, _ code: UInt16 = 0, flags: NSEvent.ModifierFlags = []) -> Bool {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
        return controller.handle(event, client: client)
    }
    func type(_ text: String) { for c in text { key(String(c)) } }
    controller.activateServer(client)
    check(controller.menu().items.first(where: { $0.title == "拼音（中文优先）" })?.state == .on, "startup defaults to pinyin")
    _ = controller.perform(NSSelectorFromString("automatic:"), with: nil)
    type("aizidongdazi"); check(client.text == "aizidongdazi" && client.marked.location == 0, "marked text")
    key(" ", 49); check(client.text == "AI 自动打字", "Space selects mixed candidate")
    _ = controller.perform(NSSelectorFromString("restore:"), with: nil)
    check(client.text == "aizidongdazi", "guarded restore returns original raw")
    type("woaini"); key("\r", 36); check(client.text.hasSuffix("woaini"), "Return keeps raw")
    type("nihao"); key("\u{1b}", 53); check(client.text.hasSuffix("woaini"), "Escape only cancels current composition")
    type("woaini"); key("", 123); // Empty event is deliberately passed to host.
    check(key("c", 8, flags: .command) == false, "Command shortcut passes through")
    check(client.text.hasSuffix("woaini"), "shortcut preserves pending raw")
    type("nihao"); controller.deactivateServer(client); check(client.text.hasSuffix("nihao"), "deactivate preserves raw")
    controller.activateServer(client); type("woaini")
    client.selection = NSRange(location: client.marked.location + 2, length: 2)
    key("x"); key("\r", 36); check(client.text.hasSuffix("woxni"), "marked selection replacement")
    controller.activateServer(client); type("nihao"); client.selection = NSRange(location: client.marked.location, length: 0)
    check(key("\u{7f}", 51), "Backspace at marked start is consumed")
    key("\r", 36); check(client.text.hasSuffix("nihao"), "marked-start Backspace does not delete host text")
    controller.activateServer(client); type("woaini"); key("\u{f702}", 123); key("\u{f702}", 123); key("x"); key("\r", 36)
    check(client.text.hasSuffix("woaixni"), "cursor editing uses grapheme boundaries")
    controller.activateServer(client); type("nihao"); key(" ", 49)
    let unchanged = client.text
    client.selection = NSRange(location: 0, length: 0)
    _ = controller.perform(NSSelectorFromString("restore:"), with: nil)
    check(client.text == unchanged, "restore refuses mismatched host selection")
    print("Native composition protocol checks OK: \(passed)")
}
