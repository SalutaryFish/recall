import SwiftUI

/// CSS `repeating-linear-gradient(<angle>deg, first 0 w1, second w1 w1+w2)` —
/// the hatch used for untracked time, thumbnails and placeholders.
struct Hatch: View {
    var angle: Double
    var first: Color
    var firstWidth: CGFloat
    var second: Color
    var secondWidth: CGFloat

    var body: some View {
        let a = first
        let b = second
        let wa = firstWidth
        let period = firstWidth + secondWidth
        let radians = angle * .pi / 180
        Canvas { context, size in
            // CSS angles: 0° points up, 90° right. Bands run perpendicular to that direction.
            let dx = sin(radians), dy = -cos(radians)
            let nx = -dy, ny = dx
            let cx = size.width / 2, cy = size.height / 2
            let half = (size.width * size.width + size.height * size.height).squareRoot() / 2 + period
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(b))
            var bands = Path()
            var t = -half
            while t < half {
                let x0 = cx + dx * t, y0 = cy + dy * t
                let x1 = cx + dx * (t + wa), y1 = cy + dy * (t + wa)
                bands.move(to: CGPoint(x: x0 - nx * half, y: y0 - ny * half))
                bands.addLine(to: CGPoint(x: x0 + nx * half, y: y0 + ny * half))
                bands.addLine(to: CGPoint(x: x1 + nx * half, y: y1 + ny * half))
                bands.addLine(to: CGPoint(x: x1 - nx * half, y: y1 - ny * half))
                bands.closeSubpath()
                t += period
            }
            context.fill(bands, with: .color(a))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension Hatch {
    /// `.thumb` / `.hero` placeholder: 45°, wash / wash-2.
    static func placeholder(band: CGFloat) -> Hatch {
        Hatch(angle: 45, first: Palette.wash, firstWidth: band, second: Palette.wash2, secondWidth: band)
    }
}
