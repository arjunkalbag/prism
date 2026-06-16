import XCTest
@testable import PrismCore

final class DetectionTests: XCTestCase {

    // Pitch classes (C = 0).
    private let C = 0, A = 9

    /// Rotate a tonic-relative profile so that index `(tonic + i) % 12` holds
    /// `profile[i]` — i.e. place the profile's tonic at the absolute pitch class
    /// `tonic` — and convert to the `[Float]` chroma the detector expects.
    private func chroma(rotating profile: [Double], toTonic tonic: Int) -> [Float] {
        var out = [Float](repeating: 0, count: 12)
        for i in 0..<12 {
            out[(tonic + i) % 12] = Float(profile[i])
        }
        return out
    }

    // MARK: - Pure profile recovers its own key

    func testKrumhanslMajorProfileRotatedToCReturnsCMajor() {
        let major = KeyProfile.krumhansl.profiles.major
        // Rotate to C (tonic 0) — equivalently, feed the profile itself as chroma.
        let input = chroma(rotating: major, toTonic: C)
        let estimate = KeyDetector().estimate(chroma: input)
        XCTAssertNotNil(estimate)
        XCTAssertEqual(estimate?.key, MusicalKey(tonic: C, mode: .major))
    }

    func testKrumhanslMinorProfileRotatedToAReturnsAMinor() {
        let minor = KeyProfile.krumhansl.profiles.minor
        // Rotate the minor profile to A (tonic 9).
        let input = chroma(rotating: minor, toTonic: A)
        let estimate = KeyDetector().estimate(chroma: input)
        XCTAssertNotNil(estimate)
        XCTAssertEqual(estimate?.key, MusicalKey(tonic: A, mode: .minor))
    }

    // MARK: - Ambiguous triad chroma

    func testCMajorTriadChromaRanksCMajorHigh() {
        // Energy on C (0), E (4), G (7); small elsewhere.
        var input = [Float](repeating: 0.02, count: 12)
        input[0] = 1.0  // C
        input[4] = 1.0  // E
        input[7] = 1.0  // G

        let estimate = KeyDetector().estimate(chroma: input)
        XCTAssertNotNil(estimate)
        guard let estimate else { return }

        let cMajor = MusicalKey(tonic: C, mode: .major)
        let aMinor = MusicalKey(tonic: A, mode: .minor)

        // The top-ranked key should be C major or its relative A minor.
        XCTAssertTrue(estimate.key == cMajor || estimate.key == aMinor,
                      "Top key was \(estimate.key.displayName); expected C major or A minor")

        // C major must be in the top 2 of the ranking.
        let top2 = estimate.ranked.prefix(2).map { $0.key }
        XCTAssertTrue(top2.contains(cMajor),
                      "C major not in top 2; top 2 = \(top2.map { $0.displayName })")
    }

    // MARK: - Degenerate input

    func testAllZeroChromaReturnsNil() {
        let estimate = KeyDetector().estimate(chroma: [Float](repeating: 0, count: 12))
        XCTAssertNil(estimate)
    }
}
