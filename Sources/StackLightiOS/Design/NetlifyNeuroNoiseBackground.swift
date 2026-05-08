import SwiftUI

struct NetlifyNeuroNoiseBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                NeuroNoiseField(phase: phase, cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34),
                                .white.opacity(0.10),
                                Color(red: 0.20, green: 0.90, blue: 0.89).opacity(0.35)
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

private struct NeuroNoiseField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat

    private let colorFront = RGBColor(red: 1.0, green: 1.0, blue: 1.0)
    private let colorMid = RGBColor(red: 0.20, green: 0.90, blue: 0.89)
    private let colorBack = RGBColor(red: 0.0, green: 0.40, blue: 0.39)
    private let brightness: CGFloat = 0.05
    private let contrast: CGFloat = 0.3
    private let speed: CGFloat = 1

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let sample: CGFloat = 2
            let t = CGFloat(0.5 * phase) * speed
            let aspect = size.width / max(size.height, 1)

            for y in stride(from: CGFloat.zero, to: size.height, by: sample) {
                for x in stride(from: CGFloat.zero, to: size.width, by: sample) {
                    let uv = CGPoint(x: (x + sample * 0.5) / max(size.width, 1),
                                     y: (y + sample * 0.5) / max(size.height, 1))
                    var shapeUV = CGPoint(x: (uv.x - 0.5) * aspect,
                                          y: uv.y - 0.5)
                    shapeUV.x *= 0.13 * 8.0
                    shapeUV.y *= 0.13 * 8.0

                    var noise = neuroShape(shapeUV, t)
                    noise = (1 + brightness) * noise * noise
                    noise = pow(max(noise, 0), 0.7 + 6 * contrast)
                    noise = min(1.4, noise)

                    let blend = smoothstep(0.7, 1.4, noise)
                    let blendFront = mix(colorMid, colorFront, blend)
                    let safeNoise = max(noise, 0)
                    var rgb = multiply(blendFront, safeNoise)
                    let opacity = clamp(safeNoise, 0, 1)
                    rgb = add(rgb, multiply(colorBack, 1 - opacity))

                    let bandingDither = (hash(CGPoint(x: x + CGFloat(phase) * 6.0, y: y)) - 0.5) / 255.0
                    rgb = RGBColor(
                        red: clamp(rgb.red + bandingDither, 0, 1),
                        green: clamp(rgb.green + bandingDither, 0, 1),
                        blue: clamp(rgb.blue + bandingDither, 0, 1)
                    )

                    let cell = CGRect(x: x, y: y, width: sample + 0.5, height: sample + 0.5)
                    context.fill(Path(cell), with: .color(Color(red: rgb.red, green: rgb.green, blue: rgb.blue)))
                }
            }
        }
    }

    private func neuroShape(_ point: CGPoint, _ t: CGFloat) -> CGFloat {
        var uv = point
        var sineAcc = CGPoint.zero
        var result = CGPoint.zero
        var scale: CGFloat = 8

        for index in 0..<15 {
            uv = rotate(uv, by: 1)
            sineAcc = rotate(sineAcc, by: 1)
            let layer = CGPoint(x: uv.x * scale + CGFloat(index) + sineAcc.x - t,
                                y: uv.y * scale + CGFloat(index) + sineAcc.y - t)
            sineAcc.x += sin(layer.x)
            sineAcc.y += sin(layer.y)
            result.x += (0.5 + 0.5 * cos(layer.x)) / scale
            result.y += (0.5 + 0.5 * cos(layer.y)) / scale
            scale *= 1.2
        }

        return result.x + result.y
    }

    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let c = cos(angle)
        let s = sin(angle)
        return CGPoint(x: point.x * c - point.y * s,
                       y: point.x * s + point.y * c)
    }

    private func hash(_ point: CGPoint) -> CGFloat {
        fract(sin(point.x * 12.9898 + point.y * 78.233) * 43758.5453)
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = clamp((value - edge0) / max(edge1 - edge0, 0.0001), 0, 1)
        return t * t * (3 - 2 * t)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func mix(_ a: RGBColor, _ b: RGBColor, _ t: CGFloat) -> RGBColor {
        let amount = clamp(t, 0, 1)
        return RGBColor(
            red: a.red + (b.red - a.red) * amount,
            green: a.green + (b.green - a.green) * amount,
            blue: a.blue + (b.blue - a.blue) * amount
        )
    }

    private func multiply(_ color: RGBColor, _ amount: CGFloat) -> RGBColor {
        RGBColor(red: color.red * amount,
                 green: color.green * amount,
                 blue: color.blue * amount)
    }

    private func add(_ a: RGBColor, _ b: RGBColor) -> RGBColor {
        RGBColor(red: clamp(a.red + b.red, 0, 1),
                 green: clamp(a.green + b.green, 0, 1),
                 blue: clamp(a.blue + b.blue, 0, 1))
    }
}

private struct RGBColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}
