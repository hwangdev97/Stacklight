import SwiftUI

struct RailwaySimplexNoiseBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                RailwaySimplexNoiseField(phase: phase, cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34),
                                .white.opacity(0.10),
                                Color(red: 0.22, green: 1.0, blue: 0.99).opacity(0.30)
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

private struct RailwaySimplexNoiseField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat

    private let colors = [
        RailwayRGB(red: 0.22, green: 1.0, blue: 0.99),     // #38fffc
        RailwayRGB(red: 0.114, green: 0.569, blue: 0.506), // #1d9181
        RailwayRGB(red: 0.063, green: 0.855, blue: 0.749)  // #10dabf
    ]
    private let stepsPerColor: CGFloat = 8
    private let speed: CGFloat = 1.26
    private let scale: CGFloat = 0.64
    private let rotation: CGFloat = 88 * .pi / 180

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let sample: CGFloat = 2
            let t = CGFloat(0.2 * phase) * speed
            let aspect = size.width / max(size.height, 1)

            for y in stride(from: CGFloat.zero, to: size.height, by: sample) {
                for x in stride(from: CGFloat.zero, to: size.width, by: sample) {
                    let uv = CGPoint(x: (x + sample * 0.5) / max(size.width, 1),
                                     y: (y + sample * 0.5) / max(size.height, 1))
                    var shapeUV = CGPoint(x: (uv.x - 0.5) * aspect,
                                          y: uv.y - 0.5)
                    shapeUV = rotate(shapeUV, by: rotation)
                    shapeUV.x = shapeUV.x / scale * 2.1
                    shapeUV.y = shapeUV.y / scale * 2.1

                    let noise = getNoise(shapeUV, t)
                    let shape = 0.5 + 0.5 * noise
                    let rgb = color(for: shape)
                    let bandingDither = (hash(CGPoint(x: x + CGFloat(phase) * 3.0, y: y)) - 0.5) / 255.0
                    let final = RailwayRGB(
                        red: clamp(rgb.red + bandingDither, 0, 1),
                        green: clamp(rgb.green + bandingDither, 0, 1),
                        blue: clamp(rgb.blue + bandingDither, 0, 1)
                    )

                    let cell = CGRect(x: x, y: y, width: sample + 0.5, height: sample + 0.5)
                    context.fill(Path(cell), with: .color(Color(red: final.red, green: final.green, blue: final.blue)))
                }
            }
        }
    }

    private func getNoise(_ point: CGPoint, _ t: CGFloat) -> CGFloat {
        let first = simplexNoise(CGPoint(x: point.x, y: point.y - 0.3 * t))
        let second = simplexNoise(CGPoint(x: point.x * 2, y: point.y * 2 + 0.32 * t))
        return 0.5 * first + 0.5 * second
    }

    private func color(for shape: CGFloat) -> RailwayRGB {
        let colorCount = CGFloat(colors.count)
        var mixer = (shape - 0.5 / colorCount) * colorCount
        let lastIndex = colors.count - 1

        if mixer < 0 || mixer > CGFloat(lastIndex) {
            var local = mixer + 1
            if mixer > CGFloat(lastIndex) {
                local = mixer - CGFloat(lastIndex)
            }
            local = stepped(local)
            return mix(colors[lastIndex], colors[0], local)
        }

        var gradient = colors[0]
        for index in 1..<colors.count {
            var local = clamp(mixer - CGFloat(index - 1), 0, 1)
            local = stepped(local)
            gradient = mix(gradient, colors[index], local)
        }
        mixer = clamp(mixer, 0, CGFloat(lastIndex))
        _ = mixer
        return gradient
    }

    private func stepped(_ value: CGFloat) -> CGFloat {
        let clamped = clamp(value, 0, 1)
        let base = floor(clamped * stepsPerColor) / stepsPerColor
        let fraction = clamped * stepsPerColor - floor(clamped * stepsPerColor)
        let hardEdge: CGFloat = fraction >= 0.5 ? 1 : 0
        return clamp(base + hardEdge / stepsPerColor, 0, 1)
    }

    private func simplexNoise(_ point: CGPoint) -> CGFloat {
        let f2: CGFloat = 0.3660254037844386
        let g2: CGFloat = 0.2113248654051871

        let skew = (point.x + point.y) * f2
        let i = floor(point.x + skew)
        let j = floor(point.y + skew)
        let unskew = (i + j) * g2
        let x0 = point.x - i + unskew
        let y0 = point.y - j + unskew

        let i1: CGFloat
        let j1: CGFloat
        if x0 > y0 {
            i1 = 1
            j1 = 0
        } else {
            i1 = 0
            j1 = 1
        }

        let x1 = x0 - i1 + g2
        let y1 = y0 - j1 + g2
        let x2 = x0 - 1 + 2 * g2
        let y2 = y0 - 1 + 2 * g2

        let n0 = simplexCorner(i: i, j: j, x: x0, y: y0)
        let n1 = simplexCorner(i: i + i1, j: j + j1, x: x1, y: y1)
        let n2 = simplexCorner(i: i + 1, j: j + 1, x: x2, y: y2)

        return clamp(70 * (n0 + n1 + n2), -1, 1)
    }

    private func simplexCorner(i: CGFloat, j: CGFloat, x: CGFloat, y: CGFloat) -> CGFloat {
        var influence = 0.5 - x * x - y * y
        if influence < 0 {
            return 0
        }
        let gradient = gradientAt(i: i, j: j)
        influence *= influence
        return influence * influence * (gradient.x * x + gradient.y * y)
    }

    private func gradientAt(i: CGFloat, j: CGFloat) -> CGPoint {
        let angle = hash(CGPoint(x: i, y: j)) * 2 * .pi
        return CGPoint(x: cos(angle), y: sin(angle))
    }

    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let c = cos(angle)
        let s = sin(angle)
        return CGPoint(x: point.x * c - point.y * s,
                       y: point.x * s + point.y * c)
    }

    private func hash(_ point: CGPoint) -> CGFloat {
        fract(sin(point.x * 127.1 + point.y * 311.7) * 43758.5453123)
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func mix(_ a: RailwayRGB, _ b: RailwayRGB, _ t: CGFloat) -> RailwayRGB {
        let amount = clamp(t, 0, 1)
        return RailwayRGB(
            red: a.red + (b.red - a.red) * amount,
            green: a.green + (b.green - a.green) * amount,
            blue: a.blue + (b.blue - a.blue) * amount
        )
    }
}

private struct RailwayRGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}
