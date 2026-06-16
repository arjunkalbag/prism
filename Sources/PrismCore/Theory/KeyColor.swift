import Foundation

/// A color in HSL space, with all components normalised:
/// `hue` in degrees `0…360`, `saturation` and `lightness` in `0…1`.
public struct HSL: Sendable, Equatable {
    public let hue: Double
    public let saturation: Double
    public let lightness: Double

    public init(hue: Double, saturation: Double, lightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }
}

/// Maps musical keys to colors — Prism's "sound has color" theme.
///
/// Each of the 12 tonics gets an evenly-spaced hue around the wheel
/// (`30°` apart), so the chromatic circle becomes a color circle.
public enum KeyColor {

    /// The hue, in degrees, for a key's tonic: `tonic × 30`, spanning `0…330`.
    public static func hue(for key: MusicalKey) -> Double {
        Double(key.tonic) * 30.0
    }

    /// The accent color for a key: its hue at a fixed, vivid saturation and lightness.
    public static func accent(for key: MusicalKey) -> HSL {
        HSL(hue: hue(for: key), saturation: 0.9, lightness: 0.66)
    }
}
