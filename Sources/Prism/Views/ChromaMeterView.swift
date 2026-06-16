import SwiftUI

/// Twelve bars — one per pitch class — shimmering with the live chroma vector.
struct ChromaMeterView: View {
    let chroma: [Float]
    let accentHue: Double

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<12, id: \.self) { i in
                    let v = chroma.indices.contains(i) ? CGFloat(max(0.06, min(1, chroma[i]))) : 0.06
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.accent(accentHue, sat: 0.85, bri: 1.0),
                                    Theme.accent(accentHue, sat: 0.9, bri: 0.5),
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: max(3, geo.size.height * v))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .opacity(0.9)
                }
            }
            .animation(.easeOut(duration: 0.22), value: chroma)
        }
    }
}
