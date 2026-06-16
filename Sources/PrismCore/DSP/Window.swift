import Foundation
import Accelerate

/// Analysis window functions used to taper audio frames before the FFT,
/// suppressing spectral leakage from the implicit rectangular truncation.
public enum Window {
    /// A periodic (DFT-even) Hann window of `count` samples.
    ///
    /// Computed with Accelerate's `vDSP_hann_window` using `vDSP_HANN_NORM`
    /// so the coefficients are suitable for direct element-wise multiplication
    /// against a real audio frame of the same length.
    ///
    /// - Parameter count: Window length in samples. Returns an empty array for
    ///   non-positive lengths.
    /// - Returns: `count` Hann coefficients.
    public static func hann(_ count: Int) -> [Float] {
        guard count > 0 else { return [] }
        var w = [Float](repeating: 0, count: count)
        vDSP_hann_window(&w, vDSP_Length(count), Int32(vDSP_HANN_NORM))
        return w
    }
}
