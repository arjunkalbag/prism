import Foundation

/// A pair of tonic-relative key-profile templates (one for major, one for
/// minor). Each is 12 weights with index 0 = the tonic, index 1 = a semitone
/// above the tonic, and so on.
public struct KeyProfileSet: Sendable {
    /// Major-mode weights, tonic-relative (index 0 = tonic).
    public let major: [Double]
    /// Minor-mode weights, tonic-relative (index 0 = tonic).
    public let minor: [Double]

    public init(major: [Double], minor: [Double]) {
        self.major = major
        self.minor = minor
    }
}

/// The named key-profile templates Prism can correlate chroma against.
///
/// All profiles are tonic-relative, so the detector rotates them to each of
/// the twelve possible tonics before correlating.
public enum KeyProfile: String, Sendable, CaseIterable {
    /// Krumhansl–Schmuckler probe-tone weights (1990) — the classic baseline.
    case krumhansl
    /// Temperley's simplified diatonic-leaning weights.
    case temperley
    /// Shaath's weights, tuned for electronic / pop key detection (KeyFinder).
    case shaath

    /// The major/minor template pair for this profile.
    public var profiles: KeyProfileSet {
        switch self {
        case .krumhansl:
            return KeyProfileSet(
                major: [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88],
                minor: [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
            )
        case .temperley:
            return KeyProfileSet(
                major: [5.0, 2.0, 3.5, 2.0, 4.5, 4.0, 2.0, 4.5, 2.0, 3.5, 1.5, 4.0],
                minor: [5.0, 2.0, 3.5, 4.5, 2.0, 4.0, 2.0, 4.5, 3.5, 2.0, 1.5, 4.0]
            )
        case .shaath:
            return KeyProfileSet(
                major: [6.6, 2.0, 3.5, 2.3, 4.6, 4.0, 2.5, 5.2, 2.4, 3.7, 2.3, 3.4],
                minor: [6.5, 2.7, 3.5, 5.4, 2.6, 3.5, 2.5, 4.8, 4.0, 2.7, 3.3, 3.2]
            )
        }
    }
}
