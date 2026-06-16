import Foundation
import ScreenCaptureKit
import CoreMedia
import PrismCore

enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case noDisplay
    case streamFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen Recording permission is required to capture system audio."
        case .noDisplay: return "No display available to attach the audio capture to."
        case .streamFailed(let m): return "Audio capture failed: \(m)"
        }
    }
}

/// Captures system audio with ScreenCaptureKit and feeds mono float samples
/// into the shared ring buffer. The app's own output is excluded so Prism
/// never analyzes itself.
final class AudioCaptureController: NSObject, SCStreamOutput, SCStreamDelegate {
    private let ringBuffer: RingBuffer
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "co.trycreate.prism.capture", qos: .userInitiated)

    /// Most recent sample rate reported by the stream's audio format.
    private(set) var sampleRate: Double = 48_000
    /// Called when the audio format's sample rate becomes known / changes.
    var onFormat: ((Double) -> Void)?
    /// Called if the stream stops unexpectedly.
    var onStop: ((Error) -> Void)?

    private var monoScratch = [Float]()  // reused across callbacks, grown as needed

    init(ringBuffer: RingBuffer) {
        self.ringBuffer = ringBuffer
        super.init()
    }

    /// Returns true if Screen Recording permission is already granted.
    func hasPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }

    /// Opens System Settings at the Screen Recording privacy pane.
    static func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    func start() async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            throw CaptureError.permissionDenied
        }
        guard let display = content.displays.first else { throw CaptureError.noDisplay }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true
        // We only care about audio; keep the mandatory video path as cheap as possible.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // ~1 fps
        config.queueDepth = 5

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
            // Some macOS versions only deliver audio while a screen output is also attached.
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
            try await stream.startCapture()
        } catch {
            throw CaptureError.streamFailed(error.localizedDescription)
        }
        self.stream = stream
    }

    func stop() {
        stream?.stopCapture(completionHandler: { _ in })
        stream = nil
        ringBuffer.reset()
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.stream = nil
        onStop?(error)
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        appendAudio(sampleBuffer)
    }

    private func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let fmt = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(fmt) else { return }
        let asbd = asbdPtr.pointee
        let rate = asbd.mSampleRate
        if rate > 0, abs(rate - sampleRate) > 1 {
            sampleRate = rate
            onFormat?(rate)
        }
        let channels = max(1, Int(asbd.mChannelsPerFrame))

        try? sampleBuffer.withAudioBufferList { abl, _ in
            guard abl.count > 0 else { return }

            if abl.count >= 2 {
                // Non-interleaved: one buffer per channel — average to mono.
                let frames = Int(abl[0].mDataByteSize) / MemoryLayout<Float>.size
                guard frames > 0 else { return }
                ensureScratch(frames)
                for f in 0..<frames { monoScratch[f] = 0 }
                var used = 0
                for b in 0..<abl.count {
                    guard let p = abl[b].mData?.assumingMemoryBound(to: Float.self) else { continue }
                    let n = Int(abl[b].mDataByteSize) / MemoryLayout<Float>.size
                    let m = min(n, frames)
                    for f in 0..<m { monoScratch[f] += p[f] }
                    used += 1
                }
                if used > 1 {
                    let inv = 1.0 / Float(used)
                    for f in 0..<frames { monoScratch[f] *= inv }
                }
                writeMono(frameCount: frames)
            } else {
                // Single buffer: interleaved (or already mono).
                guard let p = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return }
                let total = Int(abl[0].mDataByteSize) / MemoryLayout<Float>.size
                let frames = total / channels
                guard frames > 0 else { return }
                ensureScratch(frames)
                if channels == 1 {
                    for f in 0..<frames { monoScratch[f] = p[f] }
                } else {
                    let inv = 1.0 / Float(channels)
                    for f in 0..<frames {
                        var s: Float = 0
                        for c in 0..<channels { s += p[f * channels + c] }
                        monoScratch[f] = s * inv
                    }
                }
                writeMono(frameCount: frames)
            }
        }
    }

    private func ensureScratch(_ frames: Int) {
        if monoScratch.count < frames {
            monoScratch = [Float](repeating: 0, count: frames)
        }
    }

    private func writeMono(frameCount: Int) {
        monoScratch.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            ringBuffer.write(UnsafeBufferPointer(start: base, count: frameCount))
        }
    }
}
