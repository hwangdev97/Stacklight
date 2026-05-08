import SwiftUI

struct TestFlightGemSmokeBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                TestFlightGemSmokeField(phase: phase, cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34),
                                .white.opacity(0.10),
                                Color(red: 0.13, green: 0.64, blue: 0.81).opacity(0.30)
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

private struct TestFlightGemSmokeField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat

    private let colors = [
        TestFlightRGB(red: 0.961, green: 0.961, blue: 0.961), // #f5f5f5
        TestFlightRGB(red: 0.133, green: 0.639, blue: 0.808)  // #22a3ce
    ]
    private let colorBack = TestFlightRGB(red: 0.251, green: 0.573, blue: 0.788) // #4092c9
    private let colorInner = TestFlightRGB(red: 0.0, green: 0.506, blue: 0.780)  // #0081c7

    private let innerDistortion: CGFloat = 0.8
    private let outerDistortion: CGFloat = 0.6
    private let outerGlow: CGFloat = 0.55
    private let innerGlow: CGFloat = 1
    private let offset: CGFloat = 0
    private let angle: CGFloat = 0
    private let size: CGFloat = 0.8
    private let speed: CGFloat = 1
    private let scale: CGFloat = 0.6

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, canvasSize in
            let sample: CGFloat = 2
            let time = CGFloat(phase) * speed
            let aspect = canvasSize.width / max(canvasSize.height, 1)

            for y in stride(from: CGFloat.zero, to: canvasSize.height, by: sample) {
                for x in stride(from: CGFloat.zero, to: canvasSize.width, by: sample) {
                    let normalized = CGPoint(x: (x + sample * 0.5) / max(canvasSize.width, 1),
                                             y: (y + sample * 0.5) / max(canvasSize.height, 1))
                    let objectUV = CGPoint(x: (normalized.x - 0.5) * aspect / scale,
                                           y: (normalized.y - 0.5) / scale)

                    let mask = airplaneMask(objectUV)
                    let imgAlpha = mask.alpha
                    let roundness = mask.roundness

                    var smokeUV = rotate(objectUV, by: angle * .pi / 180)
                    let smokeScale = mix(4, 1, size)
                    smokeUV.x *= smokeScale
                    smokeUV.y *= smokeScale

                    var innerUV = smokeUV
                    var outerUV = smokeUV

                    innerUV.y += innerDistortion * (1 - smoothstep(0, 1, hypot(0.4 * innerUV.x, 0.4 * innerUV.y)))
                    innerUV.y -= 0.4 * innerDistortion
                    innerUV.y += 0.7 * offset * roundness

                    outerUV.y += outerDistortion * (1 - smoothstep(0, 1, hypot(0.4 * outerUV.x, 0.4 * outerUV.y)))
                    outerUV.y -= 0.4 * outerDistortion

                    let innerSwirl = innerDistortion * roundness
                    let outerSwirl = outerDistortion

                    for index in 1..<5 {
                        let i = CGFloat(index)
                        innerUV.x += innerSwirl / i * cos(time + i * 2.9 * innerUV.y)
                        innerUV.y += innerSwirl / i * cos(time + i * 1.5 * innerUV.x)
                        outerUV.x += outerSwirl / i * cos(time + i * 2.9 * outerUV.y)
                        outerUV.y += outerSwirl / i * cos(time + i * 1.5 * outerUV.x)
                    }

                    var innerShape = exp(-1.5 * dot(innerUV, innerUV))
                    var outerShape = exp(-1.5 * dot(outerUV, outerUV))
                    let outerMask = outerGlow * outerGlow * (1 - imgAlpha)
                    let innerMask = (0.01 + 0.99 * innerGlow) * imgAlpha
                    innerShape *= innerMask
                    outerShape *= outerMask

                    let smokeAmount = clamp((innerShape + outerShape) * CGFloat(colors.count), 0, 1)
                    let gradient = mix(colors[0], colors[1], smoothstep(0, 1, smokeAmount))
                    let smokeMask = smokeAmount

                    var rgb = multiply(gradient, smokeMask)
                    var opacity = smokeMask

                    let innerOpacity = imgAlpha
                    let innerColor = multiply(colorInner, innerOpacity)
                    rgb = add(rgb, multiply(innerColor, 1 - opacity))
                    opacity += innerOpacity * (1 - opacity)

                    rgb = add(rgb, multiply(colorBack, 1 - opacity))

                    let dither = (hash(CGPoint(x: x + CGFloat(phase) * 3.0, y: y)) - 0.5) / 255
                    rgb = TestFlightRGB(
                        red: clamp(rgb.red + dither, 0, 1),
                        green: clamp(rgb.green + dither, 0, 1),
                        blue: clamp(rgb.blue + dither, 0, 1)
                    )

                    let cell = CGRect(x: x, y: y, width: sample + 0.5, height: sample + 0.5)
                    context.fill(Path(cell), with: .color(Color(red: rgb.red, green: rgb.green, blue: rgb.blue)))
                }
            }

            drawAirplaneHighlight(in: &context, size: canvasSize)
        }
    }

    private func airplaneMask(_ objectUV: CGPoint) -> (alpha: CGFloat, roundness: CGFloat) {
        let p = CGPoint(x: objectUV.x / 0.8, y: objectUV.y / 0.8)
        let inside = airplaneContains(p) ? 1.0 : 0.0
        let probe: CGFloat = 0.018
        let neighbors = [
            airplaneContains(CGPoint(x: p.x + probe, y: p.y)) ? 1.0 : 0.0,
            airplaneContains(CGPoint(x: p.x - probe, y: p.y)) ? 1.0 : 0.0,
            airplaneContains(CGPoint(x: p.x, y: p.y + probe)) ? 1.0 : 0.0,
            airplaneContains(CGPoint(x: p.x, y: p.y - probe)) ? 1.0 : 0.0
        ]
        let average = (inside + neighbors.reduce(0, +)) / 5
        let edge = abs(inside - average)
        let roundness = inside > 0 ? clamp(1 - edge * 2.2, 0.12, 1) : 0
        return (average, roundness)
    }

    private func airplaneContains(_ point: CGPoint) -> Bool {
        let path = airplanePath()
        return path.contains(point)
    }

    private func airplanePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0.82, y: -0.08))
        path.addLine(to: CGPoint(x: -0.70, y: -0.50))
        path.addLine(to: CGPoint(x: -0.22, y: -0.08))
        path.addLine(to: CGPoint(x: -0.42, y: 0.46))
        path.addLine(to: CGPoint(x: 0.02, y: 0.22))
        path.addLine(to: CGPoint(x: 0.38, y: 0.58))
        path.closeSubpath()
        return path
    }

    private func drawAirplaneHighlight(in context: inout GraphicsContext, size: CGSize) {
        let aspect = size.width / max(size.height, 1)
        let planeScale = min(size.width, size.height) * 0.8 * scale
        var path = airplanePath()
        var transform = CGAffineTransform(translationX: size.width * 0.5, y: size.height * 0.5)
        transform = transform.scaledBy(x: planeScale / aspect, y: planeScale)
        path = path.applying(transform)
        context.fill(path, with: .color(Color.white.opacity(0.10)))
        context.stroke(path, with: .color(Color.white.opacity(0.20)), lineWidth: 1)
    }

    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let c = cos(angle)
        let s = sin(angle)
        return CGPoint(x: point.x * c - point.y * s,
                       y: point.x * s + point.y * c)
    }

    private func dot(_ point: CGPoint, _ other: CGPoint) -> CGFloat {
        point.x * other.x + point.y * other.y
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = clamp((value - edge0) / max(edge1 - edge0, 0.0001), 0, 1)
        return t * t * (3 - 2 * t)
    }

    private func hash(_ point: CGPoint) -> CGFloat {
        fract(sin(point.x * 127.1 + point.y * 311.7) * 43758.5453)
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * clamp(t, 0, 1)
    }

    private func mix(_ a: TestFlightRGB, _ b: TestFlightRGB, _ t: CGFloat) -> TestFlightRGB {
        TestFlightRGB(
            red: mix(a.red, b.red, t),
            green: mix(a.green, b.green, t),
            blue: mix(a.blue, b.blue, t)
        )
    }

    private func multiply(_ color: TestFlightRGB, _ amount: CGFloat) -> TestFlightRGB {
        TestFlightRGB(red: color.red * amount,
                      green: color.green * amount,
                      blue: color.blue * amount)
    }

    private func add(_ a: TestFlightRGB, _ b: TestFlightRGB) -> TestFlightRGB {
        TestFlightRGB(red: a.red + b.red,
                      green: a.green + b.green,
                      blue: a.blue + b.blue)
    }
}

private struct TestFlightRGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}
