import AppKit
import SwiftUI
import Combine

/// Owns the overlay panel: hosts the SwiftUI view, restores/saves its frame,
/// and applies opacity / click-through / visibility from the model.
@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var panel: OverlayPanel!
    private var cancellables = Set<AnyCancellable>()

    private let frameKey = "overlayFrame"

    init(model: AppModel) {
        self.model = model
        super.init()
        buildPanel()
        bind()
    }

    private func buildPanel() {
        let frame = savedFrame() ?? defaultFrame()
        let panel = OverlayPanel(contentRect: frame)

        let root = OverlayView().environmentObject(model)
        let host = NSHostingView(rootView: AnyView(root))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.delegate = self

        self.panel = panel
        applyOpacity(model.opacity)
        applyClickThrough(model.clickThrough)
        applyFloat(model.floatOnTop)
    }

    private func bind() {
        model.$opacity
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyOpacity($0) }
            .store(in: &cancellables)
        model.$clickThrough
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyClickThrough($0) }
            .store(in: &cancellables)
        model.$visible
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyVisible($0) }
            .store(in: &cancellables)
        model.$floatOnTop
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyFloat($0) }
            .store(in: &cancellables)
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleVisibility() {
        model.toggleVisible()
    }

    // MARK: Apply settings
    private func applyOpacity(_ o: Double) {
        panel.alphaValue = CGFloat(max(0.3, min(1.0, o)))
    }

    private func applyClickThrough(_ on: Bool) {
        panel.ignoresMouseEvents = on
    }

    private func applyFloat(_ on: Bool) {
        panel.level = on ? .floating : .normal
        panel.collectionBehavior = on
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.fullScreenAuxiliary]
    }

    private func applyVisible(_ visible: Bool) {
        if visible {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: NSWindowDelegate — persist frame
    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        let f = panel.frame
        UserDefaults.standard.set([f.origin.x, f.origin.y, f.size.width, f.size.height], forKey: frameKey)
    }

    private func savedFrame() -> NSRect? {
        guard let arr = UserDefaults.standard.array(forKey: frameKey) as? [Double], arr.count == 4 else { return nil }
        let rect = NSRect(x: arr[0], y: arr[1], width: arr[2], height: arr[3])
        // Guard against off-screen restores.
        guard NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else { return nil }
        return rect
    }

    private func defaultFrame() -> NSRect {
        let size = NSSize(width: 420, height: 470)
        guard let screen = NSScreen.main else {
            return NSRect(origin: .zero, size: size)
        }
        let vf = screen.visibleFrame
        let x = vf.maxX - size.width - 28
        let y = vf.maxY - size.height - 28
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
