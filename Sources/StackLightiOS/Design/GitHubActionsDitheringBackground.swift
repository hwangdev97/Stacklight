import SwiftUI

struct GitHubActionsDitheringBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        GitHubDitheringBackground(
            cornerRadius: cornerRadius,
            colorBack: Color(red: 0.325, green: 0.012, blue: 0.506),   // #530381
            colorFront: Color(red: 0.133, green: 0.188, blue: 0.808),  // #2230ce
            pxSize: 9,
            speed: 1,
            scale: 1,
            borderAccent: Color(red: 0.13, green: 0.19, blue: 0.81)
        )
    }
}

struct GitHubPullRequestDitheringBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        GitHubDitheringBackground(
            cornerRadius: cornerRadius,
            colorBack: .black,
            colorFront: Color(red: 0.573, green: 0.588, blue: 0.573), // #929692
            pxSize: 1.2,
            speed: 0.5,
            scale: 0.48,
            borderAccent: Color(red: 0.573, green: 0.588, blue: 0.573)
        )
    }
}

private struct GitHubDitheringBackground: View {
    let cornerRadius: CGFloat
    let colorBack: Color
    let colorFront: Color
    let pxSize: CGFloat
    let speed: CGFloat
    let scale: CGFloat
    let borderAccent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                DitheringDotsField(
                    phase: phase,
                    cornerRadius: cornerRadius,
                    colorBack: colorBack,
                    colorFront: colorFront,
                    pxSize: pxSize,
                    speed: speed,
                    scale: scale
                )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.32),
                                .white.opacity(0.09),
                                borderAccent.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DitheringDotsField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat
    let colorBack: Color
    let colorFront: Color
    let pxSize: CGFloat
    let speed: CGFloat
    let scale: CGFloat

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: cornerRadius), with: .color(colorBack))

            let t = CGFloat(0.5 * phase) * speed
            let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

            for y in stride(from: CGFloat.zero, to: size.height, by: pxSize) {
                for x in stride(from: CGFloat.zero, to: size.width, by: pxSize) {
                    let cellCenter = CGPoint(x: x + pxSize * 0.5, y: y + pxSize * 0.5)
                    var shapeUV = CGPoint(x: cellCenter.x - origin.x,
                                          y: cellCenter.y - origin.y)
                    shapeUV.x *= 0.05 / scale
                    shapeUV.y *= 0.05 / scale

                    let stripeIndex = floor(2 * shapeUV.x / (2 * CGFloat.pi))
                    var random = hash(stripeIndex * 10)
                    random = sign(random - 0.5) * pow(0.1 + abs(random), 0.4)

                    let wave = sin(shapeUV.x) * cos(shapeUV.y - 5 * random * t)
                    let shape = pow(abs(wave), 6)
                    let dithering = hash(CGPoint(x: cellCenter.x, y: cellCenter.y))

                    if dithering < shape {
                        let cell = CGRect(x: x, y: y, width: pxSize + 0.35, height: pxSize + 0.35)
                        context.fill(Path(cell), with: .color(colorFront))
                    }
                }
            }
        }
    }

    private func hash(_ value: CGFloat) -> CGFloat {
        fract(sin(value * 127.1) * 43758.5453)
    }

    private func hash(_ point: CGPoint) -> CGFloat {
        fract(sin(point.x * 127.1 + point.y * 311.7) * 43758.5453)
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }

    private func sign(_ value: CGFloat) -> CGFloat {
        value < 0 ? -1 : 1
    }
}
