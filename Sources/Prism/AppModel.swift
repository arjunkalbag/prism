import SwiftUI
import AppKit
import Combine
import PrismCore

enum AppMode: String, CaseIterable, Codable {
    case dj, producer
    var title: String { self == .dj ? "DJ" : "Producer" }
}

enum EngineStatus: Equatable {
    case idle          // not yet started
    case needsPermission
    case listening     // capturing, no stable key yet
    case locked        // a stable key is shown
}

/// The single source of truth: detection results + persisted UI settings,
/// wiring the audio capture, analysis engine and optional AI coach together.
@MainActor
final class AppModel: ObservableObject {
    // Detection (published to the UI)
    @Published private(set) var displayKey: MusicalKey?
    @Published private(set) var confidence: Double = 0
    @Published private(set) var bpm: Double?
    @Published private(set) var chroma: [Float] = Array(repeating: 0, count: 12)
    @Published private(set) var status: EngineStatus = .idle
    @Published var errorMessage: String?

    // Settings (persisted across launches)
    @Published var mode: AppMode = .dj            { didSet { d.set(mode.rawValue, forKey: "mode") } }
    @Published var opacity: Double = 1.0          { didSet { d.set(opacity, forKey: "opacity") } }
    // Intentionally NOT persisted — always starts off, so it can never trap
    // the cursor on launch.
    @Published var clickThrough: Bool = false
    // Always-on-top by default; intentionally NOT persisted so a stale "off"
    // can't keep it from staying on screen.
    @Published var floatOnTop: Bool = true
    @Published var aiEnabled: Bool = false        { didSet { d.set(aiEnabled, forKey: "aiEnabled") } }
    @Published var profile: KeyProfile = .shaath {
        didSet { engine.setProfile(profile); d.set(profile.rawValue, forKey: "profile") }
    }
    @Published var visible: Bool = true

    // AI state
    @Published var aiSuggestions: [AISuggestion] = []
    @Published var aiLoading = false
    @Published var aiError: String?
    var aiConfigured: Bool { coach.isConfigured }

    // Derived music theory
    var camelot: Camelot? { displayKey.map { Camelot.code(for: $0) } }
    var mixSuggestions: [MixSuggestion] { displayKey.map { MixingRules.harmonicMatches(for: $0) } ?? [] }
    var diatonic: DiatonicAnalysis? { displayKey.map { Diatonic.analyze($0) } }
    /// Hue (0…360) for the detected key; defaults to A-minor violet before lock.
    var accentHue: Double { displayKey.map { KeyColor.hue(for: $0) } ?? 270 }

    private let ringBuffer = RingBuffer(capacity: 48_000 * 12)
    private lazy var capture = AudioCaptureController(ringBuffer: ringBuffer)
    private lazy var engine = AnalysisEngine(ringBuffer: ringBuffer)
    private let coach = AICoach()
    private let d = UserDefaults.standard
    private var started = false

    init() {
        loadSettings()
    }

    func start() async {
        guard !started else { return }
        started = true

        capture.onFormat = { [weak self] rate in self?.engine.updateSampleRate(rate) }
        capture.onStop = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.status != .needsPermission { self.status = .needsPermission }
            }
        }
        engine.onUpdate = { [weak self] snap in
            Task { @MainActor in self?.apply(snap) }
        }
        engine.setProfile(profile)
        engine.start()

        let granted = await capture.hasPermission()
        guard granted else { status = .needsPermission; return }

        do {
            try await capture.start()
            engine.updateSampleRate(capture.sampleRate)
            if status != .locked { status = .listening }
        } catch CaptureError.permissionDenied {
            status = .needsPermission
        } catch {
            errorMessage = error.localizedDescription
            status = .needsPermission
        }
    }

    /// Retry capture after the user grants permission.
    func retryCapture() async {
        engine.resetSmoothing()
        do {
            try await capture.start()
            engine.updateSampleRate(capture.sampleRate)
            status = .listening
            errorMessage = nil
        } catch {
            status = .needsPermission
        }
    }

    private func apply(_ snap: AnalysisSnapshot) {
        chroma = snap.chroma
        confidence = snap.confidence
        bpm = snap.bpm
        if let k = snap.stableKey {
            if displayKey != k {
                displayKey = k
                aiSuggestions = []   // stale once the key changes
                aiError = nil
            }
            status = .locked
        } else if status == .idle {
            status = .listening
        }
    }

    /// Dev-only: inject a fixed detection result so the UI can be rendered
    /// offscreen (marketing/verification snapshots) without live audio.
    func loadPreviewState(key: MusicalKey, bpm: Double, chroma: [Float]) {
        self.displayKey = key
        self.bpm = bpm
        self.chroma = chroma
        self.confidence = 0.96
        self.status = .locked
    }

    // MARK: UI actions
    func toggleMode() { mode = (mode == .dj ? .producer : .dj) }
    func setMode(_ m: AppMode) { mode = m }
    func toggleClickThrough() { clickThrough.toggle() }
    func toggleVisible() { visible.toggle() }
    func openScreenRecordingSettings() { AudioCaptureController.openPrivacySettings() }

    /// Quit Prism entirely.
    func quit() { NSApp.terminate(nil) }

    func requestAISuggestions() {
        guard let key = displayKey, coach.isConfigured else { return }
        aiLoading = true
        aiError = nil
        Task {
            do {
                let s = try await coach.suggestions(for: key)
                await MainActor.run { self.aiSuggestions = s; self.aiLoading = false }
            } catch {
                await MainActor.run { self.aiError = error.localizedDescription; self.aiLoading = false }
            }
        }
    }

    // MARK: Persistence
    private func loadSettings() {
        if let m = d.string(forKey: "mode"), let mm = AppMode(rawValue: m) { mode = mm }
        if d.object(forKey: "opacity") != nil {
            let o = d.double(forKey: "opacity")
            opacity = o > 0.1 ? o : 1.0
        }
        aiEnabled = d.bool(forKey: "aiEnabled")
        if let p = d.string(forKey: "profile"), let pp = KeyProfile(rawValue: p) { profile = pp }
    }
}
