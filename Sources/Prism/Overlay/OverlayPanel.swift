import AppKit

/// The Prism window — a glassy, **resizable, closable** app window.
///
/// Earlier builds used a borderless non-activating overlay panel; that made the
/// app hard to control (and click-through could trap the cursor). Prism is now
/// a normal Dock app: this is a standard titled window with the traffic-light
/// buttons, so it can be focused, resized and closed like any other window.
/// (An optional "Float on top" toggle raises its level when wanted.)
final class OverlayPanel: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false   // stay visible when another app is focused
        minSize = NSSize(width: 360, height: 440)
        maxSize = NSSize(width: 720, height: 1100)
    }
}
