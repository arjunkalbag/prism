import SwiftUI
import PrismCore

/// The signature element: a color-coded Camelot wheel. Outer ring = major (B),
/// inner ring = minor (A). The current key glows; compatible slots are lit;
/// everything else dims back.
struct CamelotWheelView: View {
    let current: Camelot
    let compatibleCodes: Set<String>

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = min(size.width, size.height) / 2 - 2
            let midR = outerR * 0.64
            let innerR = outerR * 0.36

            for i in 0..<12 {
                let number = i + 1
                let hue = Double(i) * 30.0
                let start = Angle(degrees: Double(i) * 30 - 15 - 90)
                let end = Angle(degrees: Double(i) * 30 + 15 - 90)

                draw(ctx, center: center, r0: midR, r1: outerR, start: start, end: end,
                     hue: hue, code: "\(number)B")
                draw(ctx, center: center, r0: innerR, r1: midR, start: start, end: end,
                     hue: hue, code: "\(number)A")

                // Number label between the rings.
                let midAngle = Angle(degrees: Double(i) * 30 - 90)
                let lr = (midR + outerR) / 2
                let p = CGPoint(
                    x: center.x + cos(CGFloat(midAngle.radians)) * lr,
                    y: center.y + sin(CGFloat(midAngle.radians)) * lr
                )
                var label = ctx.resolve(
                    Text("\(number)").font(.prismBody(9.5))
                )
                label.shading = .color(.black.opacity(0.78))
                ctx.draw(label, at: p)
            }
        }
    }

    private func draw(_ ctx: GraphicsContext, center: CGPoint, r0: CGFloat, r1: CGFloat,
                      start: Angle, end: Angle, hue: Double, code: String) {
        var path = Path()
        path.addArc(center: center, radius: r1, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: r0, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()

        let isCurrent = (code == current.code)
        let isCompat = compatibleCodes.contains(code)
        let brightness = isCurrent ? 0.99 : 0.84
        let fill = Color(hue: hue / 360, saturation: 0.78, brightness: brightness)
        let opacity = isCurrent ? 1.0 : (isCompat ? 0.82 : 0.20)
        ctx.fill(path, with: .color(fill.opacity(opacity)))

        if isCurrent {
            ctx.stroke(path, with: .color(.white), lineWidth: 2.2)
        } else if isCompat {
            ctx.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1)
        } else {
            ctx.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 0.6)
        }
    }
}
