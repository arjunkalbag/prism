import SwiftUI

/// Shared palette + helpers. The vivid moment is the key-hue accent; everything
/// else stays calm dark glass — "sound has color."
enum Theme {
    static let ink   = Color(red: 0.96, green: 0.95, blue: 0.98)
    static let muted = Color(red: 0.67, green: 0.65, blue: 0.78)
    static let faint = Color(red: 0.49, green: 0.47, blue: 0.60)
    static let edge  = Color.white.opacity(0.14)
    static let edgeBright = Color.white.opacity(0.30)

    /// Accent color for a hue in degrees (0…360).
    static func accent(_ hueDegrees: Double, sat: Double = 0.80, bri: Double = 0.97) -> Color {
        let h = ((hueDegrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360) / 360
        return Color(hue: h, saturation: sat, brightness: bri)
    }

    /// Color for a Camelot number (1…12) around the wheel.
    static func camelotColor(_ number: Int, sat: Double = 0.78, bri: Double = 0.88) -> Color {
        accent(Double(number - 1) * 30.0, sat: sat, bri: bri)
    }
}

extension View {
    /// Secondary "instrument readout" labels (codes, list labels) — Thestral.
    /// (`weight` is accepted for call-site compatibility; Thestral is single-weight.)
    func instrument(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        self.font(.prismBody(size))
    }
}
