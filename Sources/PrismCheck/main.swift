import Foundation
import PrismCore

// A tiny dependency-free assertion harness so the deterministic core can be
// verified with only the Command Line Tools. Mirrors the XCTest suite.

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        print("  ✗ \(message())")
    }
}

func eq<T: Equatable>(_ a: T, _ b: T, _ label: String) {
    check(a == b, "\(label): expected \(b), got \(a)")
}

func section(_ name: String, _ body: () -> Void) {
    print("▸ \(name)")
    body()
}

// MARK: Camelot
section("Camelot codes") {
    eq(Camelot.code(for: MusicalKey(tonic: 0, mode: .major)).code, "8B", "C major")
    eq(Camelot.code(for: MusicalKey(tonic: 9, mode: .minor)).code, "8A", "A minor")
    eq(Camelot.code(for: MusicalKey(tonic: 7, mode: .major)).code, "9B", "G major")
    eq(Camelot.code(for: MusicalKey(tonic: 4, mode: .minor)).code, "9A", "E minor")
    eq(Camelot.code(for: MusicalKey(tonic: 2, mode: .minor)).code, "7A", "D minor")
    eq(Camelot.code(for: MusicalKey(tonic: 11, mode: .minor)).code, "10A", "B minor")
    eq(Camelot.code(for: MusicalKey(tonic: 0, mode: .minor)).code, "5A", "C minor")
    eq(Camelot.code(for: MusicalKey(tonic: 3, mode: .major)).code, "5B", "Eb major")

    // round-trip
    for key in MusicalKey.all {
        let code = Camelot.code(for: key).code
        check(Camelot(code: code)?.code == code, "round-trip \(code)")
        check(Camelot.code(for: key).key() == key, "inverse \(key.displayName)")
    }
}

// MARK: Mixing
section("Harmonic mixing (A minor / 8A)") {
    let matches = MixingRules.harmonicMatches(for: MusicalKey(tonic: 9, mode: .minor))
    let codes = matches.map { $0.camelot.code }
    check(codes.contains("8A"), "perfect 8A present")
    check(codes.contains("7A"), "smooth -1 → 7A present")
    check(codes.contains("9A"), "smooth +1 → 9A present")
    check(codes.contains("8B"), "relative → 8B present")
    // verify relation labels exist
    check(matches.contains { $0.relation == .perfect && $0.camelot.code == "8A" }, "perfect maps to 8A")
    check(matches.contains { $0.relation == .relative && $0.key == MusicalKey(tonic: 0, mode: .major) }, "relative is C major")
}

// MARK: Diatonic
section("Diatonic scales & chords") {
    let cMajor = Diatonic.analyze(MusicalKey(tonic: 0, mode: .major))
    eq(cMajor.scale.map(\.symbol), ["C", "D", "E", "F", "G", "A", "B"], "C major scale")
    eq(cMajor.chords.map(\.symbol), ["C", "Dm", "Em", "F", "G", "Am", "B°"], "C major chords")
    eq(cMajor.chords.map(\.roman), ["I", "ii", "iii", "IV", "V", "vi", "vii°"], "C major romans")

    let aMinor = Diatonic.analyze(MusicalKey(tonic: 9, mode: .minor))
    eq(aMinor.scale.map(\.symbol), ["A", "B", "C", "D", "E", "F", "G"], "A minor scale")
    eq(aMinor.chords.map(\.symbol), ["Am", "B°", "C", "Dm", "Em", "F", "G"], "A minor chords")

    let gMajor = Diatonic.analyze(MusicalKey(tonic: 7, mode: .major))
    eq(gMajor.scale.map(\.symbol), ["G", "A", "B", "C", "D", "E", "F#"], "G major scale")

    // F# major exercises sharp spelling
    let fsMajor = Diatonic.analyze(MusicalKey(tonic: 6, mode: .major))
    eq(fsMajor.scale.map(\.symbol).first, "Gb", "index-6 major tonic spelling")

    eq(cMajor.relativeKey, MusicalKey(tonic: 9, mode: .minor), "C major relative = A minor")
    eq(aMinor.relativeKey, MusicalKey(tonic: 0, mode: .major), "A minor relative = C major")
    eq(aMinor.parallelKey, MusicalKey(tonic: 9, mode: .major), "A minor parallel = A major")
}

// MARK: Key detection
section("Key detection (Krumhansl-Schmuckler)") {
    let detector = KeyDetector(profile: .krumhansl)
    let profiles = KeyProfile.krumhansl.profiles

    // Feed the C-major profile (tonic at C) as the chroma → expect C major.
    let cChroma = profiles.major.map { Float($0) }
    if let est = detector.estimate(chroma: cChroma) {
        eq(est.key, MusicalKey(tonic: 0, mode: .major), "profile→C major")
    } else { check(false, "C major estimate was nil") }

    // Rotate the minor profile to A (tonic 9) → expect A minor.
    var aMinorChroma = [Float](repeating: 0, count: 12)
    for i in 0..<12 { aMinorChroma[(9 + i) % 12] = Float(profiles.minor[i]) }
    if let est = detector.estimate(chroma: aMinorChroma) {
        eq(est.key, MusicalKey(tonic: 9, mode: .minor), "rotated→A minor")
    } else { check(false, "A minor estimate was nil") }

    // C-major triad energy → C major should be in the top 2 candidates.
    var triad = [Float](repeating: 0.05, count: 12)
    triad[0] = 1; triad[4] = 1; triad[7] = 1
    if let est = detector.estimate(chroma: triad) {
        let top2 = Set(est.ranked.prefix(2).map { $0.key })
        check(top2.contains(MusicalKey(tonic: 0, mode: .major)), "C-major triad → C major in top 2")
    } else { check(false, "triad estimate was nil") }

    // Silence → nil
    check(detector.estimate(chroma: [Float](repeating: 0, count: 12)) == nil, "all-zero chroma → nil")
}

// MARK: DSP smoke (FFT + chroma on a synthesized A440 tone)
section("DSP smoke (A440 sine → chroma peak at A)") {
    let sampleRate = 48_000.0
    let fftSize = 4096
    var samples = [Float](repeating: 0, count: fftSize)
    let freq = 440.0
    for n in 0..<fftSize {
        samples[n] = Float(sin(2.0 * Double.pi * freq * Double(n) / sampleRate))
    }
    let extractor = ChromaExtractor(fftSize: fftSize, sampleRate: sampleRate)
    let chroma = extractor.chroma(from: samples)
    check(chroma.count == 12, "chroma has 12 bins")
    if chroma.count == 12 {
        let maxIdx = chroma.indices.max(by: { chroma[$0] < chroma[$1] }) ?? -1
        eq(maxIdx, 9, "A440 peaks at pitch class A (9)")
    }
}

// MARK: Full chroma → key pipeline on synthesized tones
section("Chroma → key (synthesized notes)") {
    let sr = 48_000.0
    let N = 4096
    func render(_ freqs: [Double]) -> [Float] {
        var sig = [Float](repeating: 0, count: N)
        for n in 0..<N {
            var s = 0.0
            for f in freqs { s += sin(2.0 * Double.pi * f * Double(n) / sr) }
            sig[n] = Float(s / Double(max(1, freqs.count)))
        }
        return sig
    }
    let extractor = ChromaExtractor(fftSize: N, sampleRate: sr)
    let detector = KeyDetector(profile: .shaath)

    // C major triad (C4 E4 G4) → C major should rank at the top (allow its
    // relative A minor as a near-tie, but C major must be present in the top 2).
    let cTriad = extractor.chroma(from: render([261.63, 329.63, 392.00]))
    if let est = detector.estimate(chroma: cTriad) {
        let top2 = Set(est.ranked.prefix(2).map { $0.key })
        check(top2.contains(MusicalKey(tonic: 0, mode: .major)),
              "C-E-G triad → C major in top 2 (got \(est.key.displayName))")
    } else { check(false, "triad estimate was nil") }

    // A slightly sharp (off-A440) single tone should still fold to A, thanks to
    // tuning correction: 451.6 Hz ≈ A + 45 cents.
    let sharpA = extractor.chroma(from: render([451.6]))
    let maxIdx = sharpA.indices.max(by: { sharpA[$0] < sharpA[$1] }) ?? -1
    eq(maxIdx, 9, "off-tuning A (451.6 Hz) still peaks at pitch class A")
}

// MARK: Tempo
section("Tempo (120 BPM click track → ~120 BPM)") {
    let sr = 48_000.0
    let bpm = 120.0
    let period = Int(60.0 / bpm * sr)          // 24000 samples between beats
    let totalSamples = Int(sr * 12)            // 12 s
    var sig = [Float](repeating: 0, count: totalSamples)
    var beat = 0
    let burst = Int(0.04 * sr)
    while beat < sig.count {
        for j in 0..<burst where beat + j < sig.count {
            let t = Double(j) / sr
            let env = exp(-t * 30.0)
            sig[beat + j] += Float(env * sin(2.0 * Double.pi * 1000.0 * t)) * 0.8
        }
        beat += period
    }
    let tempo = TempoEstimator(sampleRate: sr)
    var i = 0
    while i < sig.count {
        let n = min(4800, sig.count - i)
        tempo.append(Array(sig[i..<i + n]), count: n)
        i += n
    }
    if let detected = tempo.currentBPM() {
        check(abs(detected - 120.0) < 4.0, "detected BPM ≈ 120 (got \(detected))")
    } else {
        check(false, "tempo returned nil")
    }
}

print("")
if failures == 0 {
    print("✅ All \(checks) checks passed.")
    exit(0)
} else {
    print("❌ \(failures) of \(checks) checks failed.")
    exit(1)
}
