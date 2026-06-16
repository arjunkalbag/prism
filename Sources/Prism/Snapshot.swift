import AppKit
import SwiftUI
import CoreText
import PrismCore

/// Offscreen marketing / verification renderer.
///
/// Triggered by `PRISM_RENDER_DIR` and invoked from `applicationWillFinishLaunching`,
/// which calls `exit(0)` immediately after — so it renders the real SwiftUI views
/// to PNGs during launch and never shows a window or enters a blocking run loop.
/// Mirrors Halo's `SnapshotRenderer`. The frosted `VisualEffectBlur` is a live
/// `NSView` that `ImageRenderer` can't capture, so a dark "DAW behind glass"
/// gradient stands in behind the panel, exactly as the app reads in use.
@MainActor
enum PrismSnapshot {
    static func run(outputDir: String) {
        registerFonts()
        OverlayView.isSnapshot = true

        let model = AppModel()
        let chroma: [Float] = [0.78, 0.10, 0.52, 0.16, 0.71, 0.58, 0.09, 0.86, 0.13, 1.0, 0.15, 0.63]

        // DJ — Bb minor (Camelot 3A), pink accent.
        model.loadPreviewState(key: MusicalKey(tonic: 10, mode: .minor), bpm: 131, chroma: chroma)
        model.setMode(.dj)
        render(model: model, size: NSSize(width: 440, height: 560), to: "\(outputDir)/prism-dj.png")

        // Producer — C# minor (Camelot 12A), orange accent.
        model.loadPreviewState(key: MusicalKey(tonic: 1, mode: .minor), bpm: 134, chroma: chroma)
        model.setMode(.producer)
        render(model: model, size: NSSize(width: 440, height: 640), to: "\(outputDir)/prism-producer.png")

        NSLog("Prism: snapshots written to \(outputDir)")
    }

    private static func registerFonts() {
        let envDir = ProcessInfo.processInfo.environment["PRISM_FONT_DIR"]
        for name in ["Typefesse_Claire-Obscure", "Pretendard-Bold"] {
            var url: URL?
            if let envDir { url = URL(fileURLWithPath: "\(envDir)/\(name).otf") }
            if url == nil || !FileManager.default.fileExists(atPath: url!.path) {
                url = Bundle.main.url(forResource: name, withExtension: "otf", subdirectory: "Fonts")
                    ?? Bundle.main.url(forResource: name, withExtension: "otf")
            }
            if let url, FileManager.default.fileExists(atPath: url.path) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    private static func render(model: AppModel, size: NSSize, to path: String) {
        let corner: CGFloat = 16
        let content = ZStack {
            // Stand-in for the blurred desktop behind the real frosted glass.
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.08),
                                    Color(red: 0.12, green: 0.10, blue: 0.17)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            OverlayView().environmentObject(model)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                Circle().fill(Color(red: 0.16, green: 0.80, blue: 0.27))
            }
            .frame(height: 12)
            .padding(14)
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            NSLog("Prism: render failed for \(path)"); return
        }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
