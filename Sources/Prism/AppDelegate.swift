import AppKit

/// Bootstraps the overlay panel, global hotkeys, and the capture/analysis
/// engine once the app finishes launching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var overlay: OverlayController?
    private var hotkeys: HotkeyManager?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Dev: render the real views offscreen and exit before any window shows.
        if let dir = ProcessInfo.processInfo.environment["PRISM_RENDER_DIR"] {
            PrismSnapshot.run(outputDir: dir)
            exit(0)
        }
        PrismFonts.registerBundled()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular Dock app: shows in the Dock and ⌘-Tab, has an app menu,
        // and is closable like any other app.
        NSApp.setActivationPolicy(.regular)

        let overlay = OverlayController(model: model)
        overlay.show()
        self.overlay = overlay

        let hk = HotkeyManager()
        hk.onToggleVisibility = { [weak model] in model?.toggleVisible() }
        hk.onToggleClickThrough = { [weak model] in model?.toggleClickThrough() }
        hk.register()
        self.hotkeys = hk

        Task { await model.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true   // closing the window quits Prism
    }
}
