import AppKit
import InputMethodKit

final class CompositionCoordinator: NSObject {
    private weak var clientObject: AnyObject?
    private func client() -> IMKTextInput? { clientObject as? IMKTextInput }
    private var raw = ""
    private var cursor = 0
    private var selected = 0
    private var candidates: [Candidate] = []
    private var mode = "chinese"
    private var revision = 0
    private var sessionId = UUID().uuidString
    private let panel = CandidatePanel()
    private var savedCommit: (raw: String, text: String, range: NSRange, clientId: ObjectIdentifier)?
    private let unspecified = NSRange(location: NSNotFound, length: 0)
    private var userEntries: [[String: String]] { Preferences.entries() }
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        clientObject = client as AnyObject
        if event.modifierFlags.intersection([.command, .control, .option]).isEmpty == false {
            if !raw.isEmpty { commit(raw, to: client) }
            return false
        }
        // Dead keys and empty events must stay with the host.
        guard let characters = event.characters, !characters.isEmpty else { return false }
        var editingRange = NSRange(location: cursor, length: 0)
        if !raw.isEmpty {
            let marked = client.markedRange(), selection = client.selectedRange()
            if marked.location != NSNotFound, selection.location != NSNotFound,
               selection.location >= marked.location, NSMaxRange(selection) <= NSMaxRange(marked) {
                let local = NSRange(location: selection.location - marked.location, length: selection.length)
                if NSMaxRange(local) <= (raw as NSString).length { editingRange = local; cursor = local.location }
            }
        }
        switch event.keyCode {
        case 49: // Space confirms selected candidate.
            guard !raw.isEmpty else { return false }
            commit(candidates.indices.contains(selected) ? candidates[selected].text : raw, to: client); return true
        case 36, 76:
            guard !raw.isEmpty else { return false }
            commit(raw, to: client); return true
        case 53:
            guard !raw.isEmpty else { return false }
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: unspecified)
            clear(); return true
        case 51:
            guard !raw.isEmpty else { return false }
            guard cursor > 0 || editingRange.length > 0 else { return true }
            let string = raw as NSString
            let deleted = editingRange.length > 0 ? editingRange : string.rangeOfComposedCharacterSequence(at: cursor - 1)
            raw = string.replacingCharacters(in: deleted, with: ""); cursor = deleted.location
            refresh(client); return true
        case 117:
            guard !raw.isEmpty else { return false }
            let string = raw as NSString
            guard cursor < string.length || editingRange.length > 0 else { return true }
            let deleted = editingRange.length > 0 ? editingRange : string.rangeOfComposedCharacterSequence(at: cursor)
            raw = string.replacingCharacters(in: deleted, with: ""); cursor = deleted.location
            refresh(client); return true
        case 123, 124:
            guard !raw.isEmpty else { return false }
            let string = raw as NSString
            if event.keyCode == 123, cursor > 0 { cursor = string.rangeOfComposedCharacterSequence(at: cursor - 1).location }
            if event.keyCode == 124, cursor < string.length { cursor = NSMaxRange(string.rangeOfComposedCharacterSequence(at: cursor)) }
            mark(client); return true
        case 125, 126:
            guard !candidates.isEmpty else { return false }
            selected = (selected + (event.keyCode == 125 ? 1 : candidates.count - 1)) % candidates.count
            show(client); return true
        default: break
        }
        if mode == "english" { return false }
        guard characters.unicodeScalars.allSatisfy({ $0.value >= 32 && !CharacterSet.controlCharacters.contains($0) }) else { return false }
        if raw.isEmpty && characters.range(of: "^[A-Za-züÜ]$", options: .regularExpression) == nil { return false }
        let string = raw as NSString
        raw = string.replacingCharacters(in: editingRange, with: characters)
        cursor = editingRange.location + (characters as NSString).length
        savedCommit = nil
        refresh(client)
        return true
    }
    private func refresh(_ client: IMKTextInput) {
        revision += 1; selected = 0
        candidates = Engine.shared.decode(raw, cursor: cursor, mode: mode, sessionId: sessionId, revision: revision, entries: userEntries)?.candidates ?? []
        mark(client); show(client)
    }
    private func mark(_ client: IMKTextInput) {
        client.setMarkedText(raw, selectionRange: NSRange(location: cursor, length: 0), replacementRange: unspecified)
    }
    private func show(_ client: IMKTextInput) {
        guard !raw.isEmpty else { panel.hide(); return }
        var rect = NSRect.zero
        _ = client.attributes(forCharacterIndex: cursor, lineHeightRectangle: &rect)
        // No reliable insertion point means no floating panel; Space/Return still work.
        guard rect.width.isFinite, rect.height.isFinite, rect.height > 0 else { panel.hide(); return }
        let expectedRevision = revision
        panel.show(candidates, selected: selected, anchor: rect) { [weak self, weak object = client as AnyObject] index in
            guard let self, let object, let current = object as? IMKTextInput,
                  self.revision == expectedRevision, self.candidates.indices.contains(index) else { return }
            self.commit(self.candidates[index].text, to: current)
        }
    }
    private func commit(_ text: String, to client: IMKTextInput) {
        let original = raw
        let range = client.markedRange()
        client.insertText(text, replacementRange: unspecified)
        clear()
        if range.location != NSNotFound {
            savedCommit = (original, text, NSRange(location: range.location, length: (text as NSString).length), ObjectIdentifier(client as AnyObject))
        }
    }
    private func clear() { raw = ""; cursor = 0; selected = 0; candidates = []; revision += 1; panel.hide() }
    override func commitComposition(_ sender: Any!) {
        guard !raw.isEmpty, let client = sender as? IMKTextInput else { return }
        commit(raw, to: client)
    }
    func activateServer(_ sender: Any!) { clientObject = sender as AnyObject?; sessionId = UUID().uuidString; savedCommit = nil; clear() }
    func deactivateServer(_ sender: Any!) {
        if !raw.isEmpty, let client = sender as? IMKTextInput { commit(raw, to: client) }
        savedCommit = nil; clear()
    }
    func inputControllerWillClose() { savedCommit = nil; clear() }
    func hidePalettes() { panel.hide() }
    func menu() -> NSMenu! {
        let menu = NSMenu(title: "顺位输入法")
        for (title, action) in [("自动混输", #selector(automatic(_:))), ("英文锁定", #selector(english(_:))), ("拼音（中文优先）", #selector(chinese(_:))), ("恢复刚提交的原文", #selector(restore(_:))), ("添加用户词条", #selector(addEntry(_:))), ("管理用户词条", #selector(manageEntries(_:)))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; item.state = (action == #selector(chinese(_:)) && mode == "chinese") || (action == #selector(english(_:)) && mode == "english") || (action == #selector(automatic(_:)) && mode == "auto") ? .on : .off; menu.addItem(item)
        }
        return menu
    }
    private func changeMode(_ value: String) {
        if let client = client(), !raw.isEmpty { commit(raw, to: client) }
        mode = value; savedCommit = nil
    }
    @objc private func automatic(_ sender: Any?) { changeMode("auto") }
    @objc private func english(_ sender: Any?) { changeMode("english") }
    @objc private func chinese(_ sender: Any?) { changeMode("chinese") }
    @objc private func addEntry(_ sender: Any?) { changeMode(mode); Preferences.add() }
    @objc private func manageEntries(_ sender: Any?) { changeMode(mode); Preferences.manage() }
    @objc private func restore(_ sender: Any?) {
        guard let saved = savedCommit, let client = client(),
              ObjectIdentifier(client as AnyObject) == saved.clientId,
              client.selectedRange() == NSRange(location: NSMaxRange(saved.range), length: 0),
              client.attributedSubstring(from: saved.range)?.string == saved.text else { NSSound.beep(); return }
        client.insertText(saved.raw, replacementRange: saved.range)
        savedCommit = nil
    }
}
