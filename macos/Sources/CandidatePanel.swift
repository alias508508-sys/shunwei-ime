import AppKit

final class CandidatePanel {
    private let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 220), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var callback: ((Int) -> Void)?
    init() {
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    func show(_ candidates: [Candidate], selected: Int, anchor: NSRect, onSelect: @escaping (Int) -> Void) {
        guard !candidates.isEmpty else { hide(); return }
        callback = onSelect
        let height = CGFloat(candidates.count * 36 + 12)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: height))
        for (index, candidate) in candidates.enumerated() {
            let button = NSButton(title: candidate.text + (candidate.id == "raw" ? "  [原文]" : ""), target: self, action: #selector(selectCandidate(_:)))
            button.tag = index
            button.frame = NSRect(x: 6, y: height - CGFloat((index + 1) * 36) - 6, width: 348, height: 34)
            button.alignment = .left
            button.bezelStyle = .regularSquare
            button.font = .systemFont(ofSize: 15)
            button.contentTintColor = index == selected ? .systemBlue : .labelColor
            view.addSubview(button)
        }
        panel.contentView = view
        panel.setContentSize(NSSize(width: 360, height: height))
        let screens = NSScreen.screens
        let screen = screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let x = min(max(anchor.minX, bounds.minX), bounds.maxX - 360)
        let y = anchor.minY - height >= bounds.minY ? anchor.minY - height : min(anchor.maxY, bounds.maxY - height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }
    @objc private func selectCandidate(_ sender: NSButton) { callback?(sender.tag) }
    func hide() { panel.orderOut(nil); callback = nil }
}
