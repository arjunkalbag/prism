import Foundation
import Accelerate

/// A reusable real-input FFT that returns the magnitude spectrum of a
/// pre-windowed frame.
///
/// The split-complex storage and the vDSP FFT setup are allocated once in
/// `init` and reused on every call, so `magnitudes(of:)` performs no
/// per-call allocation beyond the returned array. The legacy vDSP C API is
/// used (radix-2, in-place real FFT via `vDSP_fft_zrip`).
///
/// This type is **not** `Sendable`: it owns mutable scratch buffers and a
/// C FFT setup, and is intended to be used from a single analysis queue.
public final class FFTProcessor {
    /// FFT length in samples; a power of two.
    public let size: Int

    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private let halfSize: Int

    // Reused scratch buffers — never reallocated after init.
    private var realp: [Float]
    private var imagp: [Float]
    private var mags: [Float]

    /// Creates a processor for frames of `size` samples.
    ///
    /// - Parameter size: FFT length; **must** be a power of two and at least 2.
    public init(size: Int) {
        precondition(size >= 2, "FFT size must be at least 2")
        precondition((size & (size - 1)) == 0, "FFT size must be a power of two")
        self.size = size
        self.halfSize = size / 2
        self.log2n = vDSP_Length(log2(Float(size)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("vDSP_create_fftsetup failed for size \(size)")
        }
        self.setup = setup
        self.realp = [Float](repeating: 0, count: halfSize)
        self.imagp = [Float](repeating: 0, count: halfSize)
        self.mags = [Float](repeating: 0, count: halfSize)
    }

    /// Returns the magnitude spectrum (`size/2` bins) of an already-windowed
    /// real frame of length `size`.
    ///
    /// - Parameter windowed: Real samples, already multiplied by an analysis
    ///   window. Its count must equal `size`.
    /// - Returns: A fresh array of `size/2` non-negative magnitudes (bin 0 is
    ///   DC, packed with Nyquist by the real FFT but treated as a magnitude here).
    public func magnitudes(of windowed: [Float]) -> [Float] {
        precondition(windowed.count == size, "input length must equal FFT size")

        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!,
                                            imagp: imagPtr.baseAddress!)

                // Pack the interleaved real input into split-complex form.
                windowed.withUnsafeBufferPointer { inPtr in
                    inPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self,
                                                         capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }

                // Forward in-place real FFT.
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                // Magnitude-squared per bin, then sqrt and the 0.5 scale that
                // compensates for zrip's inherent factor-of-two on the output.
                mags.withUnsafeMutableBufferPointer { magPtr in
                    vDSP_zvmags(&split, 1, magPtr.baseAddress!, 1, vDSP_Length(halfSize))
                    var n = Int32(halfSize)
                    vvsqrtf(magPtr.baseAddress!, magPtr.baseAddress!, &n)
                    var scale: Float = 0.5
                    vDSP_vsmul(magPtr.baseAddress!, 1, &scale,
                               magPtr.baseAddress!, 1, vDSP_Length(halfSize))
                }
            }
        }

        return Array(mags)
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }
}
