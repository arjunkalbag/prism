// Renders the Prism app icon: a full-bleed spectrum (conic) gradient squircle
// with a soft top-left sheen and a fine inner highlight — matching the glyph on
// the Prism & Halo product page.
//   swift Tools/MakeIcon.swift /tmp/prism_icon_1024.png
import SwiftUI
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/prism_icon_1024.png"
let S: CGFloat = 1024
let radius = S * 0.2237            // macOS continuous squircle

func hex(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b) }
let coral  = hex(1.000, 0.541, 0.420)   // #ff8a6b
let amber  = hex(1.000, 0.784, 0.341)   // #ffc857
let mint   = hex(0.337, 0.839, 0.651)   // #56d6a6
let azure  = hex(0.353, 0.663, 1.000)   // #5aa9ff
let violet = hex(0.624, 0.549, 1.000)   // #9f8cff
let rose   = hex(1.000, 0.478, 0.776)   // #ff7ac6

let icon = ZStack {
    // Spectrum conic sweep (CSS: conic-gradient(from 210deg, …)).
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(AngularGradient(
            gradient: Gradient(colors: [coral, amber, mint, azure, violet, rose, coral]),
            center: .center,
            angle: .degrees(126)))
    // Top-left sheen.
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .fill(RadialGradient(
            gradient: Gradient(colors: [.white.opacity(0.55), .white.opacity(0.0)]),
            center: UnitPoint(x: 0.30, y: 0.24),
            startRadius: 0, endRadius: S * 0.52))
    // Fine inner highlight edge.
    RoundedRectangle(cornerRadius: radius, style: .continuous)
        .strokeBorder(.white.opacity(0.45), lineWidth: S * 0.010)
}
.frame(width: S, height: S)

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1
    guard let img = renderer.nsImage,
          let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("icon render failed\n".data(using: .utf8)!); exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
}
