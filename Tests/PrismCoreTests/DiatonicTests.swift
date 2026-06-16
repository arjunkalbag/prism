import XCTest
@testable import PrismCore

final class DiatonicTests: XCTestCase {

    // Pitch classes (C = 0).
    private let C = 0, G = 7, A = 9

    // MARK: - C major

    func testCMajorScaleSymbols() {
        let analysis = Diatonic.analyze(MusicalKey(tonic: C, mode: .major))
        XCTAssertEqual(analysis.scale.map { $0.symbol },
                       ["C", "D", "E", "F", "G", "A", "B"])
    }

    func testCMajorChordSymbolsAndRomans() {
        let analysis = Diatonic.analyze(MusicalKey(tonic: C, mode: .major))
        XCTAssertEqual(analysis.chords.map { $0.symbol },
                       ["C", "Dm", "Em", "F", "G", "Am", "B°"])
        XCTAssertEqual(analysis.chords.map { $0.roman },
                       ["I", "ii", "iii", "IV", "V", "vi", "vii°"])
    }

    // MARK: - A minor

    func testAMinorScaleSymbols() {
        let analysis = Diatonic.analyze(MusicalKey(tonic: A, mode: .minor))
        XCTAssertEqual(analysis.scale.map { $0.symbol },
                       ["A", "B", "C", "D", "E", "F", "G"])
    }

    func testAMinorChordSymbols() {
        let analysis = Diatonic.analyze(MusicalKey(tonic: A, mode: .minor))
        XCTAssertEqual(analysis.chords.map { $0.symbol },
                       ["Am", "B°", "C", "Dm", "Em", "F", "G"])
    }

    // MARK: - G major

    func testGMajorScaleSymbols() {
        let analysis = Diatonic.analyze(MusicalKey(tonic: G, mode: .major))
        XCTAssertEqual(analysis.scale.map { $0.symbol },
                       ["G", "A", "B", "C", "D", "E", "F#"])
    }

    // MARK: - Relative / parallel keys

    func testRelativeAndParallelKeys() {
        let cMajor = MusicalKey(tonic: C, mode: .major)
        let aMinor = MusicalKey(tonic: A, mode: .minor)
        let aMajor = MusicalKey(tonic: A, mode: .major)

        // C major relative == A minor.
        XCTAssertEqual(Diatonic.analyze(cMajor).relativeKey, aMinor)
        // A minor relative == C major.
        XCTAssertEqual(Diatonic.analyze(aMinor).relativeKey, cMajor)
        // A minor parallel == A major.
        XCTAssertEqual(Diatonic.analyze(aMinor).parallelKey, aMajor)
    }
}
