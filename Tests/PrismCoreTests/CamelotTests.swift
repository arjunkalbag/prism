import XCTest
@testable import PrismCore

final class CamelotTests: XCTestCase {

    // MARK: - Helpers

    private func code(_ tonic: Int, _ mode: Mode) -> String {
        Camelot.code(for: MusicalKey(tonic: tonic, mode: mode)).code
    }

    // Pitch classes (C = 0).
    private let C = 0, Eb = 3, E = 4, G = 7, A = 9, B = 11, D = 2

    // MARK: - code(for:) for known keys

    func testCodeForKnownKeys() {
        XCTAssertEqual(code(C, .major),  "8B",  "C major")
        XCTAssertEqual(code(A, .minor),  "8A",  "A minor")
        XCTAssertEqual(code(G, .major),  "9B",  "G major")
        XCTAssertEqual(code(E, .minor),  "9A",  "E minor")
        XCTAssertEqual(code(D, .minor),  "7A",  "D minor")
        XCTAssertEqual(code(B, .minor),  "10A", "B minor")
        XCTAssertEqual(code(C, .minor),  "5A",  "C minor")
        XCTAssertEqual(code(Eb, .major), "5B",  "Eb major")
    }

    // MARK: - Camelot(code:) round-trips

    func testCodeRoundTripsForAllKeys() {
        for key in MusicalKey.all {
            let camelot = Camelot.code(for: key)
            let parsed = Camelot(code: camelot.code)
            XCTAssertNotNil(parsed, "Failed to parse \(camelot.code)")
            XCTAssertEqual(parsed?.number, camelot.number)
            XCTAssertEqual(parsed?.mode, camelot.mode)
            XCTAssertEqual(parsed?.code, camelot.code)
            // And the resolved key should round-trip back to the original.
            XCTAssertEqual(parsed?.key(), key)
        }
    }

    func testCodeRoundTripsSpecificCodes() {
        for raw in ["8A", "8B", "9B", "9A", "7A", "10A", "5A", "5B", "1A", "12B"] {
            let parsed = Camelot(code: raw)
            XCTAssertNotNil(parsed, "Expected to parse \(raw)")
            XCTAssertEqual(parsed?.code, raw, "\(raw) did not round-trip")
        }
    }

    func testCodeIsCaseInsensitive() {
        XCTAssertEqual(Camelot(code: "8a")?.code, "8A")
        XCTAssertEqual(Camelot(code: "12b")?.code, "12B")
    }

    // MARK: - harmonicMatches(for: A minor)

    func testHarmonicMatchesForAMinor() {
        let aMinor = MusicalKey(tonic: A, mode: .minor) // 8A
        let matches = MixingRules.harmonicMatches(for: aMinor)
        let codes = matches.map { $0.camelot.code }

        // Perfect 8A.
        XCTAssertTrue(codes.contains("8A"), "Expected perfect match 8A; got \(codes)")
        // Smooth neighbors: 7A (D minor) and 9A (E minor).
        XCTAssertTrue(codes.contains("7A"), "Expected smooth neighbor 7A; got \(codes)")
        XCTAssertTrue(codes.contains("9A"), "Expected smooth neighbor 9A; got \(codes)")
        // Relative 8B (C major).
        XCTAssertTrue(codes.contains("8B"), "Expected relative 8B; got \(codes)")

        // Verify the resolved keys for the required relations.
        func key(forCode wanted: String) -> MusicalKey? {
            matches.first { $0.camelot.code == wanted }?.key
        }
        XCTAssertEqual(key(forCode: "8A"), MusicalKey(tonic: A, mode: .minor))  // A minor
        XCTAssertEqual(key(forCode: "7A"), MusicalKey(tonic: D, mode: .minor))  // D minor
        XCTAssertEqual(key(forCode: "9A"), MusicalKey(tonic: E, mode: .minor))  // E minor
        XCTAssertEqual(key(forCode: "8B"), MusicalKey(tonic: C, mode: .major))  // C major
    }
}
