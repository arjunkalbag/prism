import Foundation
import PrismCore

/// A single analysis result handed to the UI.
struct AnalysisSnapshot {
    let chroma: [Float]          // 12 bins, latest frame (for the meter)
    let stableKey: MusicalKey?   // smoothed/held key; nil while still "listening…"
    let confidence: Double
    let bpm: Double?
}

/// Pulls audio from the ring buffer on its own queue, runs chroma → key
/// detection (Krumhansl-Schmuckler) and tempo, and **holds one key per song**:
///
///  - Detection runs on a slow exponential average of chroma (a long tonal
///    memory), so brief riffs / passing chords don't move the reading.
///  - A hysteresis lock means once a key is shown it only changes if a rival
///    key wins *consistently for several seconds* **and** out-correlates the
///    held key by a clear margin — so it never flickers mid-song.
///  - A sustained silence gap (track change) resets the lock so the next song
///    locks fresh and fast.
final class AnalysisEngine {
    private let ringBuffer: RingBuffer
    private let fftSize = 4096
    private let hopInterval = 0.12  // seconds between key analyses

    var onUpdate: ((AnalysisSnapshot) -> Void)?

    // DSP — rebuilt lazily when the sample rate becomes known / changes.
    // Sha'ath profiles (à la KeyFinder) track popular/electronic music better
    // than the classical Krumhansl set; the menu can switch it.
    private var detector = KeyDetector(profile: .shaath)
    private var chromaExtractor: ChromaExtractor?
    private var tempo: TempoEstimator?
    private var builtRate: Double = 0
    private var pendingRate: Double = 48_000
    private var needsRebuild = true

    private let queue = DispatchQueue(label: "co.trycreate.prism.analysis", qos: .userInitiated)
    private var timer: DispatchSourceTimer?

    private var window: [Float]
    private var tempoChunk: [Float] = []
    private var maxTempoChunk = 48_000
    private var lastTempoTotal = 0

    // --- Detection smoothing / per-song lock ---
    private let emaAlpha: Float = 0.04        // ~3 s tonal memory
    private let tonalPeakFloor: Float = 0.32  // skip near-flat (non-tonal) frames
    private var emaChroma = [Float](repeating: 0, count: 12)
    private var hasEMA = false

    private var pendingCandidate: MusicalKey?
    private var pendingCount = 0
    private var challenger: MusicalKey?
    private var challengerCount = 0
    private var locked: MusicalKey?
    private var lastConfidence = 0.0

    private let initialLockFrames = 8         // ~1 s of agreement → first lock
    private let switchFrames = 30             // ~3.6 s before a rival can take over
    private let switchMargin = 0.04           // …and it must out-correlate by this

    // --- Silence handling (track-change reset) ---
    private let silenceRMS: Float = 0.003
    private var silentFrames = 0
    private let silenceResetFrames = 12       // ~1.4 s of silence → fresh song

    init(ringBuffer: RingBuffer) {
        self.ringBuffer = ringBuffer
        window = [Float](repeating: 0, count: fftSize)
    }

    func setProfile(_ p: KeyProfile) {
        queue.async { self.detector = KeyDetector(profile: p) }
    }

    func updateSampleRate(_ rate: Double) {
        queue.async {
            guard rate > 0, abs(rate - self.builtRate) > 1 else { return }
            self.pendingRate = rate
            self.needsRebuild = true
        }
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.4, repeating: hopInterval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Drop all accumulated detection + tempo state.
    func resetSmoothing() {
        queue.async { self.hardReset() }
    }

    private func hardReset() {
        hasEMA = false
        for i in 0..<12 { emaChroma[i] = 0 }
        pendingCandidate = nil
        pendingCount = 0
        challenger = nil
        challengerCount = 0
        locked = nil
        lastConfidence = 0
        tempo?.reset()
        lastTempoTotal = ringBuffer.totalWritten
    }

    private func rebuildIfNeeded() {
        guard needsRebuild || chromaExtractor == nil else { return }
        let rate = pendingRate > 0 ? pendingRate : 48_000
        chromaExtractor = ChromaExtractor(fftSize: fftSize, sampleRate: rate)
        tempo = TempoEstimator(sampleRate: rate)
        maxTempoChunk = max(fftSize, Int(rate))            // up to ~1 s per tick
        tempoChunk = [Float](repeating: 0, count: maxTempoChunk)
        lastTempoTotal = ringBuffer.totalWritten
        builtRate = rate
        needsRebuild = false
    }

    private func tick() {
        rebuildIfNeeded()
        guard let chromaExtractor,
              ringBuffer.count >= fftSize,
              ringBuffer.latest(fftSize, into: &window) else { return }

        // Tempo runs on the ordered sample stream at its own fine hop.
        feedTempo()
        let bpm = tempo?.currentBPM()

        // Silence gate — a sustained gap means a new track is coming.
        let rms = computeRMS(window)
        if rms < silenceRMS {
            silentFrames += 1
            if silentFrames == silenceResetFrames { hardReset() }
            publish(chroma: [Float](repeating: 0, count: 12), bpm: bpm)
            return
        }
        silentFrames = 0

        // Chroma → slow tonal average → detection.
        let chroma = chromaExtractor.chroma(from: window)

        // Only fold tonal frames into the running average. A near-flat chroma
        // (percussion, noise, a drum break) carries no key and would just
        // dilute the estimate, so it's shown on the meter but skipped here.
        let peak = chroma.max() ?? 0
        if peak >= tonalPeakFloor {
            let alpha: Float = hasEMA ? emaAlpha : 1.0
            for i in 0..<12 { emaChroma[i] = alpha * chroma[i] + (1 - alpha) * emaChroma[i] }
            hasEMA = true
        }

        if hasEMA, let est = detector.estimate(chroma: emaChroma) {
            lastConfidence = est.confidence
            applyHysteresis(est)
        }

        publish(chroma: chroma, bpm: bpm)
    }

    private func applyHysteresis(_ est: KeyEstimate) {
        let winner = est.key
        if locked == nil {
            // Not locked yet: require a short run of agreement.
            if winner == pendingCandidate { pendingCount += 1 }
            else { pendingCandidate = winner; pendingCount = 1 }
            if pendingCount >= initialLockFrames {
                locked = winner
                challenger = nil
                challengerCount = 0
            }
        } else if winner == locked {
            // Held key still winning — reset any challenger.
            challenger = nil
            challengerCount = 0
        } else {
            // A rival is winning: only switch if it persists *and* beats the
            // held key's correlation by a clear margin.
            if winner == challenger { challengerCount += 1 }
            else { challenger = winner; challengerCount = 1 }

            let lockedScore = est.ranked.first(where: { $0.key == locked })?.score ?? -1
            let winnerScore = est.ranked.first?.score ?? 0
            if challengerCount >= switchFrames, (winnerScore - lockedScore) > switchMargin {
                locked = winner
                challenger = nil
                challengerCount = 0
            }
        }
    }

    private func feedTempo() {
        guard let tempo else { return }
        let total = ringBuffer.totalWritten
        if total < lastTempoTotal { lastTempoTotal = total }   // buffer was reset
        var newCount = total - lastTempoTotal
        guard newCount > 0 else { return }
        if newCount > maxTempoChunk { newCount = maxTempoChunk }  // fell behind: cap
        lastTempoTotal = total
        if ringBuffer.latest(newCount, into: &tempoChunk) {
            tempo.append(tempoChunk, count: newCount)
        }
    }

    private func computeRMS(_ buf: [Float]) -> Float {
        var sum: Float = 0
        for v in buf { sum += v * v }
        return (sum / Float(buf.count)).squareRoot()
    }

    private func publish(chroma: [Float], bpm: Double?) {
        let snap = AnalysisSnapshot(chroma: chroma, stableKey: locked, confidence: lastConfidence, bpm: bpm)
        onUpdate?(snap)
    }
}
