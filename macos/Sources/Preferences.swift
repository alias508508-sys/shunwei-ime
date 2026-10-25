import AppKit

final class Preferences {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Shunwrite/entries.json")
    static func entries() -> [[String: String]] {
        guard let data = try? Data(contentsOf: url), let rows = try? JSONDecoder().decode([[String: String]].self, from: data) else { return [] }
        return Array(rows.prefix(100))
    }
    static func save(_ rows: [[String: String]]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
        } catch { let alert = NSAlert(); alert.messageText = "词条保存失败"; alert.informativeText = error.localizedDescription; alert.runModal() }
    }
    static func add() {
        let alert = NSAlert(); alert.messageText = "添加顺位词条"; alert.informativeText = "输入文字和拼音，音节用空格分开。仅保存在此 Mac。"
        alert.addButton(withTitle: "添加"); alert.addButton(withTitle: "取消")
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 90)); view.orientation = .vertical; view.spacing = 8
        let text = NSTextField(); text.placeholderString = "文字，例如：顺位"
        let pinyin = NSTextField(); pinyin.placeholderString = "shun wei"
        view.addArrangedSubview(text); view.addArrangedSubview(pinyin); alert.accessoryView = view
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let word = text.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let pin = pinyin.stringValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, word.count <= 32, pin.count <= 128, pin.range(of: "^[a-zv]+(?:[ '\\-][a-zv]+)*$", options: .regularExpression) != nil else {
            let warning = NSAlert(); warning.messageText = "请填写文字及有效拼音"; warning.runModal(); return
        }
        var rows = entries().filter { $0["text"] != word || $0["pinyin"] != pin }
        rows.append(["text": word, "pinyin": pin]); save(Array(rows.suffix(100)))
    }
    static func manage() {
        let rows = entries()
        let alert = NSAlert(); alert.messageText = "你的顺位词条"
        alert.informativeText = rows.isEmpty ? "还没有添加词条。" : "选择一个词条后删除；或清空全部词条。"
        alert.addButton(withTitle: "关闭"); alert.addButton(withTitle: "删除选中"); alert.addButton(withTitle: "清空全部")
        let choices = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 30))
        choices.addItems(withTitles: rows.map { "\($0["text"] ?? "") · \($0["pinyin"] ?? "")" }); alert.accessoryView = choices
        let response = alert.runModal()
        if response == .alertSecondButtonReturn, rows.indices.contains(choices.indexOfSelectedItem) { var next = rows; next.remove(at: choices.indexOfSelectedItem); save(next) }
        if response == .alertThirdButtonReturn { save([]) }
    }
}
