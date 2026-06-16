import Foundation

/// The harmonic relationship between a source key and a suggested mix target,
/// expressed in Camelot-wheel terms.
public enum MixRelation: String, Sendable, CaseIterable {
    /// Same Camelot code — a flawless blend.
    case perfect
    /// One step counter-clockwise (`n-1`) — drops energy slightly.
    case energyDown
    /// One step clockwise (`n+1`) — lifts energy slightly.
    case energyUp
    /// Same number, opposite letter — the relative major/minor.
    case relative
    /// Two steps clockwise (`n+2`) — a noticeable energy jump.
    case energyBoost
    /// Seven steps clockwise (`n+7`, equivalently `n-5`) — the dominant.
    case dominant

    /// Human-readable label shown in the UI.
    public var label: String {
        switch self {
        case .perfect:     return "perfect"
        case .energyDown:  return "smooth -1"
        case .energyUp:    return "smooth +1"
        case .relative:    return "relative"
        case .energyBoost: return "energy +2"
        case .dominant:    return "dominant"
        }
    }
}

/// A single harmonic-mixing suggestion: a target key, its Camelot position,
/// and how it relates to the source key.
public struct MixSuggestion: Sendable, Equatable, Identifiable {
    public var id: String { camelot.code }
    public let key: MusicalKey
    public let camelot: Camelot
    public let relation: MixRelation
    public let label: String

    public init(key: MusicalKey, camelot: Camelot, relation: MixRelation, label: String) {
        self.key = key
        self.camelot = camelot
        self.relation = relation
        self.label = label
    }
}

/// Harmonic-mixing logic derived from the Camelot wheel.
public enum MixingRules {

    /// Wrap an arbitrary integer into the Camelot range `1…12`, handling negatives.
    private static func wrap(_ n: Int) -> Int {
        (((n - 1) % 12) + 12) % 12 + 1
    }

    /// The set of harmonically compatible keys for `key`, in a fixed order:
    /// perfect, energy −1, energy +1, relative, energy +2, dominant.
    public static func harmonicMatches(for key: MusicalKey) -> [MixSuggestion] {
        let source = Camelot.code(for: key)
        let n = source.number

        // (relation, target number, mode for the target)
        let rules: [(MixRelation, Int, Mode)] = [
            (.perfect,     n,      key.mode),
            (.energyDown,  n - 1,  key.mode),
            (.energyUp,    n + 1,  key.mode),
            (.relative,    n,      key.mode == .major ? .minor : .major),
            (.energyBoost, n + 2,  key.mode),
            (.dominant,    n + 7,  key.mode),
        ]

        return rules.map { relation, rawNumber, mode in
            let camelot = Camelot(number: wrap(rawNumber), mode: mode)
            return MixSuggestion(
                key: camelot.key(),
                camelot: camelot,
                relation: relation,
                label: relation.label
            )
        }
    }
}
