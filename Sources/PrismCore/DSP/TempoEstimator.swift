import Foundation
import Accelerate

/// A secondary BPM readout from a spectral-flux onset envelope and
/// lag-domain autocorrelation.
///
/// Unlike a key estimate, tempo needs a *finely* sampled onset envelope, so the
/// estimator owns its own short hop (512 samples ≈ 11 ms) rather than piggy-
/// backing on the coarse key-analysis tick. Feed it the raw mono sample stream
/// in order via `append(_:count:)`; query `currentBPM()` for the latest value.
///
/// Accuracy comes from three things: a fine hop (fine lag resolution), a
/// log-normal tempo preference weight centred on ~120 BPM (which resolves the
/// classic half/double-tempo octave error), and a median over recent estimates
/// (which removes frame-to-frame jitter). It never throws or blocks: with too
/// little history it returns `nil`.
///
/// Not `Sendable`: it keeps mutable history and lives on a single analysis queue.
public final class TempoEstimator {
    private let sampleRate: Double
    private let hop = 512
    private let frameSize = 1024
    private let frameRate: Double          // onset frames per second
    private let capacity: Int              // envelope ring capacity (frames)

    private let fft: FFTProcessor
    private let hann: [Float]

    private var pending: [Float] = []      // un-hopped samples awaiting a frame
    private var windowBuf: [Float]
    private var previousMag: [Float] = []
    private var envelope: [Float] = []     // onset-strength history

    // Lag band for 70…180 BPM.
    private let minLag: Int
    private let maxLag: Int
    private let minFrames: Int

    // Median smoothing of the final estimate.
    private var bpmHistory: [Double] = []
    private let smoothingCount = 8

    public init(sampleRate: Double, historySeconds: Double = 10.0) {
        precondition(sampleRate > 0, "sampleRate must be positive")
        self.sampleRate = sampleRate
        self.frameRate = sampleRate / Double(hop)
        self.capacity = max(1, Int((historySeconds * frameRate).rounded()))
        self.fft = FFTProcessor(size: frameSize)
        self.hann = Window.hann(frameSize)
        self.windowBuf = [Float](repeating: 0, count: frameSize)

        let lo = Int((60.0 * frameRate / 180.0).rounded(.down))
        let hi = Int((60.0 * frameRate / 70.0).rounded(.up))
        self.minLag = max(1, lo)
        self.maxLag = max(self.minLag + 1, hi)
        self.minFrames = max(self.maxLag + 1, Int((4.0 * frameRate).rounded()))

        pending.reserveCapacity(frameSize * 8)
        envelope.reserveCapacity(capacity)
    }

    /// Ingest the next `count` mono samples (in order). Complete hops are turned
    /// into onset-strength values via spectral flux.
    public func append(_ samples: [Float], count: Int) {
        guard count > 0 else { return }
        let n = min(count, samples.count)
        pending.append(contentsOf: samples[0..<n])

        var pos = 0
        while pos + frameSize <= pending.count {
            for i in 0..<frameSize { windowBuf[i] = pending[pos + i] * hann[i] }
            let mag = fft.magnitudes(of: windowBuf)
            if previousMag.count == mag.count {
                var diff = [Float](repeating: 0, count: mag.count)
                vDSP_vsub(previousMag, 1, mag, 1, &diff, 1, vDSP_Length(mag.count)) // mag - previous
                var zero: Float = 0
                vDSP_vthr(diff, 1, &zero, &diff, 1, vDSP_Length(diff.count))         // max(0, .)
                var flux: Float = 0
                vDSP_sve(diff, 1, &flux, vDSP_Length(diff.count))
                appendEnvelope(flux)
            }
            previousMag = mag
            pos += hop
        }
        if pos > 0 { pending.removeFirst(pos) }
    }

    /// Latest tempo estimate in BPM (~70…180), or `nil` until enough history.
    public func currentBPM() -> Double? {
        let n = envelope.count
        guard n >= minFrames else { return nil }

        var mean: Float = 0
        vDSP_meanv(envelope, 1, &mean, vDSP_Length(n))
        var centered = [Float](repeating: 0, count: n)
        var negMean = -mean
        vDSP_vsadd(envelope, 1, &negMean, &centered, 1, vDSP_Length(n))

        var energy: Float = 0
        vDSP_svesq(centered, 1, &energy, vDSP_Length(n))
        guard energy > 0 else { return nil }

        let hiLag = min(maxLag, n - 1)
        guard hiLag >= minLag else { return nil }

        var bestLag = minLag
        var bestScore = -Float.greatestFiniteMagnitude
        centered.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for lag in minLag...hiLag {
                var acc: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &acc, vDSP_Length(n - lag))
                // Normalize for overlap count so long lags aren't penalized, then
                // weight by a tempo-preference curve to break octave ambiguity.
                let norm = acc / Float(n - lag)
                let bpm = 60.0 * frameRate / Double(lag)
                let score = norm * Float(tempoWeight(bpm))
                if score > bestScore {
                    bestScore = score
                    bestLag = lag
                }
            }
        }

        guard bestScore > 0, bestLag > 0 else { return nil }
        let raw = 60.0 * frameRate / Double(bestLag)

        bpmHistory.append(raw)
        if bpmHistory.count > smoothingCount {
            bpmHistory.removeFirst(bpmHistory.count - smoothingCount)
        }
        let sorted = bpmHistory.sorted()
        let median = sorted[sorted.count / 2]
        return (median * 10).rounded() / 10   // 0.1-BPM resolution
    }

    public func reset() {
        pending.removeAll(keepingCapacity: true)
        previousMag.removeAll(keepingCapacity: true)
        envelope.removeAll(keepingCapacity: true)
        bpmHistory.removeAll(keepingCapacity: true)
    }

    /// Log-normal weight centred on 120 BPM — gently prefers musically common
    /// tempos so the autocorrelation peak picks the true beat, not its octave.
    private func tempoWeight(_ bpm: Double) -> Double {
        let z = log2(bpm / 120.0) / 0.9
        return exp(-0.5 * z * z)
    }

    private func appendEnvelope(_ value: Float) {
        if envelope.count >= capacity {
            envelope.removeFirst(envelope.count - capacity + 1)
        }
        envelope.append(value)
    }
}
