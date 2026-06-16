import Foundation

/// A key paired with its detection score (Pearson correlation against the
/// chroma vector). Used to rank all 24 candidates.
public struct ScoredKey: Sendable, Equatable, Hashable {
    public let key: MusicalKey
    public let score: Double
    public init(key: MusicalKey, score: Double) {
        self.key = key
        self.score = score
    }
}

/// The result of running key detection over an accumulated chroma vector.
public struct KeyEstimate: Sendable, Equatable {
    /// Best-scoring key.
    public let key: MusicalKey
    /// 0…1 — how decisively the winner beat the runner-up.
    public let confidence: Double
    /// All 24 keys, sorted by score descending.
    public let ranked: [ScoredKey]

    public init(key: MusicalKey, confidence: Double, ranked: [ScoredKey]) {
        self.key = key
        self.confidence = confidence
        self.ranked = ranked
    }
}
