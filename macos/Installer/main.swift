import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let fileManager = FileManager.default
let source = Bundle.main.resourceURL!.appendingPathComponent("Shunwrite.app")
let directory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods")
let target = directory.appendingPathComponent("Shunwrite.app")
let identifier = "org.shunwrite.inputmethod.Shunwrite"
if CommandLine.arguments.contains("--check-payload") {
    guard Bundle(url: source)?.bundleIdentifier == identifier,
          fileManager.isExecutableFile(atPath: source.appendingPathComponent("Contents/MacOS/Shunwrite").path) else { exit(1) }
    print("Installer payload verified; no installation performed")
    exit(0)
}
app.activate(ignoringOtherApps: true)
let welcome = NSAlert()
welcome.messageText = "安装顺位输入法"
welcome.informativeText = "安装到当前用户，不需要管理员密码。\n\n启动默认拼音，支持中英文混输。安装后请在系统设置 → 键盘 → 文本输入中手动添加。\n\n这是未经 Apple 公证的开发测试版，真实应用兼容性仍需验证。"
welcome.addButton(withTitle: "安装")
welcome.addButton(withTitle: "取消")
guard welcome.runModal() == .alertFirstButtonReturn else { exit(0) }
var backup: URL?
do {
    guard Bundle(url: source)?.bundleIdentifier == identifier else { throw NSError(domain: "Shunwei", code: 1, userInfo: [NSLocalizedDescriptionKey: "安装包内容不完整。请重新下载。"] ) }
    if !NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty {
        throw NSError(domain: "Shunwei", code: 2, userInfo: [NSLocalizedDescriptionKey: "顺位仍在运行。请先切换到其他输入法并退出顺位；如无法退出，请退出登录后重新运行安装器。"])
    }
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    if fileManager.fileExists(atPath: target.path) {
        guard Bundle(url: target)?.bundleIdentifier == identifier else { throw NSError(domain: "Shunwei", code: 3, userInfo: [NSLocalizedDescriptionKey: "目标目录存在其他应用，已停止安装。"] ) }
        let destination = directory.appendingPathComponent("Shunwrite-backup-\(UUID().uuidString).app")
        try fileManager.moveItem(at: target, to: destination)
        backup = destination
    }
    do { try fileManager.copyItem(at: source, to: target) }
    catch {
        if fileManager.fileExists(atPath: target.path) { try? fileManager.removeItem(at: target) }
        if let backup { try? fileManager.moveItem(at: backup, to: target) }
        throw error
    }
    let success = NSAlert(); success.messageText = "顺位输入法已安装"
    success.informativeText = "请在系统设置 → 键盘 → 文本输入 → 编辑 → 添加输入源中找到“顺位输入法”。\n\n若暂未出现，请退出登录后重新登录。当前尚未自动切换你的输入法。"
    success.addButton(withTitle: "打开键盘设置"); success.addButton(withTitle: "完成")
    if success.runModal() == .alertFirstButtonReturn, let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") { NSWorkspace.shared.open(url) }
} catch {
    let alert = NSAlert(); alert.messageText = "未完成安装"; alert.informativeText = error.localizedDescription; alert.runModal(); exit(1)
}
