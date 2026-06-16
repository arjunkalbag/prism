import Foundation
import Accelerate

/// Turns one window of audio samples into a normalized 12-bin chroma vector.
///
/// A chroma (pitch-class profile) folds the FFT magnitude spectrum onto the
/// twelve pitch classes, discarding octave information. Bin 0 is C, bin 9 is A.
/// The result is L2-normalized so downstream correlation against key profiles
/// is scale-invariant.
///
/// Accuracy comes from four steps beyond a naive fold:
///   1. **Amplitude compression** (√magnitude) so a loud bass note or transient
///      doesn't drown out the harmonic content that actually defines the key.
///   2. **Tuning estimation** — the global deviation of spectral energy from
///      equal-tempered semitone centres is measured per frame and corrected, so
///      tracks not tuned to A440 (very common) still land on the right classes.
///   3. **Interpolated binning** — each bin's energy is split between its two
///      nearest pitch classes by distance, rather than hard-rounded (which
///      throws away anything between centres).
///   4. **Octave weighting** — a raised-cosine emphasis on the tonal midrange
///      (~C2–C7) damps sub-bass/kick rumble and cymbal/hiss that carry no key.
///
/// Not `Sendable`: it owns an `FFTProcessor` and scratch buffers, and is meant
/// to run on a single analysis queue.
public final class ChromaExtractor {
    /// FFT length used for analysis (also the required input frame length).
    public let fftSize: Int
    /// Sample rate the bin maps were built for.
    public let sampleRate: Double

    private let window: [Float]
    private let fft: FFTProcessor
    private var windowed: [Float]

    // Precomputed per usable bin (those inside the analysed frequency band).
    private let usableBins: [Int]        // FFT bin indices
    private let binPitch: [Double]       // continuous pitch class 0..<12
    private let binWeight: [Double]      // octave weighting

    /// Lowest analysed frequency (~C2). Below this is mostly bass/kick rumble.
    private static let minFrequency: Double = 65.0
    /// Highest analysed frequency (~C8). Above this is mostly noise/cymbals.
    private static let maxFrequency: Double = 4186.0

    public init(fftSize: Int = 4096, sampleRate: Double) {
        precondition(fftSize >= 2, "fftSize must be at least 2")
        precondition((fftSize & (fftSize - 1)) == 0, "fftSize must be a power of two")
        precondition(sampleRate > 0, "sampleRate must be positive")

        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.window = Window.hann(fftSize)
        self.fft = FFTProcessor(size: fftSize)
        self.windowed = [Float](repeating: 0, count: fftSize)

        let half = fftSize / 2
        var bins: [Int] = []
        var pitches: [Double] = []
        var weights: [Double] = []
        bins.reserveCapacity(half)
        for k in 1..<half {
            let freq = Double(k) * sampleRate / Double(fftSize)
            guard freq >= ChromaExtractor.minFrequency,
                  freq <= ChromaExtractor.maxFrequency else { continue }
            let midi = 69.0 + 12.0 * log2(freq / 440.0)
            var pc = midi.truncatingRemainder(dividingBy: 12.0)
            if pc < 0 { pc += 12 }
            bins.append(k)
            pitches.append(pc)
            weights.append(ChromaExtractor.octaveWeight(midi: midi))
        }
        self.usableBins = bins
        self.binPitch = pitches
        self.binWeight = weights
    }

    /// Raised-cosine weight peaking around midi 66 (~F#4) and tapering to a low
    /// floor at the extremes — keeps the tonally informative midrange dominant.
    private static func octaveWeight(midi: Double) -> Double {
        let center = 66.0
        let halfSpan = 32.0
        let x = (midi - center) / halfSpan
        if x <= -1 || x >= 1 { return 0.3 }
        return 0.3 + 0.7 * (0.5 * (1 + cos(Double.pi * x)))
    }

    /// Extracts a 12-bin chroma vector from one frame of samples.
    ///
    /// - Parameter samples: A frame whose count must equal `fftSize`.
    /// - Returns: 12 L2-normalized values (index 0 = C … 9 = A). All zero if the
    ///   frame carries no energy in the analysed band.
    public func chroma(from samples: [Float]) -> [Float] {
        precondition(samples.count == fftSize, "samples.count must equal fftSize")

        samples.withUnsafeBufferPointer { sPtr in
            window.withUnsafeBufferPointer { wPtr in
                windowed.withUnsafeMutableBufferPointer { outPtr in
                    vDSP_vmul(sPtr.baseAddress!, 1, wPtr.baseAddress!, 1,
                              outPtr.baseAddress!, 1, vDSP_Length(fftSize))
                }
            }
        }
        let mags = fft.magnitudes(of: windowed)

        let n = usableBins.count
        var comp = [Double](repeating: 0, count: n)

        // Pass 1: compressed, octave-weighted magnitudes + tuning estimate.
        // √magnitude is scale-equivariant, so the final L2 normalisation cancels
        // any global gain while still taming loud partials.
        //
        // Tuning is the *circular* mean of energy position on the semitone grid
        // (period = 1 semitone). A plain signed mean would break for tones near
        // the half-semitone boundary — exactly where FFT leakage straddles two
        // bins with opposite-sign deviations — so the circular form is essential.
        let twoPi = 2.0 * Double.pi
        var sumSin = 0.0
        var sumCos = 0.0
        for j in 0..<n {
            let mag = Double(mags[usableBins[j]])
            let m = (mag > 0 ? mag.squareRoot() : 0) * binWeight[j]
            comp[j] = m
            let angle = twoPi * binPitch[j]
            sumSin += m * sin(angle)
            sumCos += m * cos(angle)
        }
        let tuning = (sumSin == 0 && sumCos == 0) ? 0.0 : atan2(sumSin, sumCos) / twoPi

        // Pass 2: tuning-corrected, interpolated fold onto 12 classes.
        var chroma = [Double](repeating: 0, count: 12)
        for j in 0..<n {
            var pos = binPitch[j] - tuning
            pos = pos.truncatingRemainder(dividingBy: 12.0)
            if pos < 0 { pos += 12 }
            let lower = Int(pos.rounded(.down)) % 12
            let frac = pos - pos.rounded(.down)
            chroma[lower] += comp[j] * (1 - frac)
            chroma[(lower + 1) % 12] += comp[j] * frac
        }

        var out = [Float](repeating: 0, count: 12)
        var sumSq = 0.0
        for v in chroma { sumSq += v * v }
        let norm = sumSq.squareRoot()
        guard norm > 0 else { return out }
        for i in 0..<12 { out[i] = Float(chroma[i] / norm) }
        return out
    }
}
