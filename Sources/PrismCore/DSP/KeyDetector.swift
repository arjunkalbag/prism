import Foundation

/// Estimates the musical key of a chroma vector by correlating it against the
/// twenty-four rotated key profiles (12 tonics × major/minor) and ranking them.
///
/// The score for each candidate is the Pearson correlation between the 12-d
/// chroma and the candidate's rotated template; higher is better.
public struct KeyDetector: Sendable {
    /// The 24 rotated templates, precomputed once per profile choice.
    /// Element order matches `MusicalKey.all`: C major, C minor, C# major, …
    private let templates: [(key: MusicalKey, profile: [Double])]

    /// Creates a detector backed by the given profile set.
    ///
    /// - Parameter profile: Which key-profile template family to correlate
    ///   against. Defaults to Krumhansl–Schmuckler.
    public init(profile: KeyProfile = .krumhansl) {
        let set = profile.profiles
        var built: [(MusicalKey, [Double])] = []
        built.reserveCapacity(24)
        for key in MusicalKey.all {
            let base = key.mode == .major ? set.major : set.minor
            // Rotate so rotated[(tonic + i) % 12] = base[i]; the tonic of the
            // key aligns to its absolute pitch class.
            var rotated = [Double](repeating: 0, count: 12)
            for i in 0..<12 {
                rotated[(key.tonic + i) % 12] = base[i]
            }
            built.append((key, rotated))
        }
        self.templates = built
    }

    /// Estimates the key of a chroma vector.
    ///
    /// - Parameter chroma: 12 values, index 0 = C. May be any non-negative
    ///   magnitudes; need not be normalized (Pearson correlation is invariant
    ///   to scale and offset).
    /// - Returns: A `KeyEstimate` with the winner, a 0…1 confidence, and all 24
    ///   keys ranked by score; or `nil` if `chroma` is empty, the wrong length,
    ///   or carries no variance (e.g. all-zero / flat).
    public func estimate(chroma: [Float]) -> KeyEstimate? {
        guard chroma.count == 12 else { return nil }

        let x = chroma.map(Double.init)
        let meanX = x.reduce(0, +) / 12.0
        let dx = x.map { $0 - meanX }
        let varX = dx.reduce(0) { $0 + $1 * $1 }
        // All-zero or perfectly flat chroma carries no key information.
        guard varX > 0 else { return nil }
        let sigmaX = varX.squareRoot()

        var scored: [ScoredKey] = []
        scored.reserveCapacity(24)
        for (key, profile) in templates {
            let r = KeyDetector.pearson(dx: dx, sigmaX: sigmaX, y: profile)
            scored.append(ScoredKey(key: key, score: r))
        }

        scored.sort { $0.score > $1.score }

        guard let winner = scored.first else { return nil }
        let best = winner.score
        let second = scored.count > 1 ? scored[1].score : best

        // Confidence: the normalized margin between the top two correlations.
        // Pearson r lives in [-1, 1], so dividing the raw gap by 0.2 maps a
        // "clearly separated" gap (~0.06–0.18, typical for real music) to a
        // pleasant 0.3–0.9 range, clamped to [0, 1]. This is intentionally
        // gap-based rather than absolute-r-based so a globally low-correlation
        // frame that still has one standout key reads as confident.
        let confidence = max(0.0, min(1.0, (best - second) / 0.2))

        return KeyEstimate(key: winner.key, confidence: confidence, ranked: scored)
    }

    /// Pearson correlation of a pre-centered `x` (with its sigma) against a raw
    /// `y`. Returns 0 when `y` has zero variance.
    private static func pearson(dx: [Double], sigmaX: Double, y: [Double]) -> Double {
        let meanY = y.reduce(0, +) / Double(y.count)
        var cov = 0.0
        var varY = 0.0
        for i in 0..<y.count {
            let dy = y[i] - meanY
            cov += dx[i] * dy
            varY += dy * dy
        }
        guard varY > 0, sigmaX > 0 else { return 0 }
        return cov / (sigmaX * varY.squareRoot())
    }
}
