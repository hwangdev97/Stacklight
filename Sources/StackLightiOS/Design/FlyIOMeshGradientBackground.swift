import SwiftUI

struct FlyIOMeshGradientBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                FlyIOMeshGradientField(phase: phase, cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.38),
                                .white.opacity(0.12),
                                Color(red: 0.97, green: 0.31, blue: 0.57).opacity(0.34)
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

private struct FlyIOMeshGradientField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat

    private let colors = [
        FlyIORGB(red: 0.878, green: 0.918, blue: 1.0),   // #e0eaff
        FlyIORGB(red: 0.604, green: 0.114, blue: 0.361), // #9a1d5c
        FlyIORGB(red: 0.969, green: 0.314, blue: 0.573), // #f75092
        FlyIORGB(red: 0.871, green: 0.678, blue: 1.0)    // #deadff
    ]
    private let distortion: CGFloat = 0.8
    private let swirl: CGFloat = 0.1
    private let speed: CGFloat = 1

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let sample: CGFloat = 2
            let firstFrameOffset: CGFloat = 41.5
            let t = 0.5 * (CGFloat(phase) * speed + firstFrameOffset)
            let aspect = size.width / max(size.height, 1)

            for y in stride(from: CGFloat.zero, to: size.height, by: sample) {
                for x in stride(from: CGFloat.zero, to: size.width, by: sample) {
                    let normalized = CGPoint(x: (x + sample * 0.5) / max(size.width, 1),
                                             y: (y + sample * 0.5) / max(size.height, 1))
                    var uv = CGPoint(x: (normalized.x - 0.5) * aspect + 0.5,
                                     y: normalized.y)

                    let radius = smoothstep(0, 1, distance(uv, CGPoint(x: 0.5, y: 0.5)))
                    let center = 1 - radius
                    for index in 1...2 {
                        let i = CGFloat(index)
                        let sy = smoothstep(0, 1, uv.y)
                        let sx = smoothstep(0, 1, uv.x)
                        uv.x += distortion * center / i * sin(t + i * 0.4 * sy) * cos(0.2 * t + i * 2.4 * sy)
                        uv.y += distortion * center / i * cos(t + i * 2.0 * sx)
                    }

                    var uvRotated = CGPoint(x: uv.x - 0.5, y: uv.y - 0.5)
                    let angle = 3 * swirl * radius
                    uvRotated = rotate(uvRotated, by: -angle)
                    uvRotated = CGPoint(x: uvRotated.x + 0.5, y: uvRotated.y + 0.5)

                    var color = FlyIORGB(red: 0, green: 0, blue: 0)
                    var totalWeight: CGFloat = 0
                    for index in colors.indices {
                        let pos = position(for: index, t: t)
                        var dist = distance(uvRotated, pos)
                        dist = pow(dist, 3.5)
                        let weight = 1 / (dist + 0.001)
                        color = add(color, multiply(colors[index], weight))
                        totalWeight += weight
                    }

                    let final = multiply(color, 1 / max(0.0001, totalWeight))
                    let cell = CGRect(x: x, y: y, width: sample + 0.5, height: sample + 0.5)
                    context.fill(Path(cell), with: .color(Color(red: final.red, green: final.green, blue: final.blue)))
                }
            }
        }
    }

    private func position(for index: Int, t: CGFloat) -> CGPoint {
        let i = CGFloat(index)
        let a = i * 0.37
        let b = 0.6 + fract(i / 3) * 0.9
        let c = 0.8 + fract((i + 1) / 4)
        let x = sin(t * b + a)
        let y = cos(t * c + a * 1.5)
        return CGPoint(x: 0.5 + 0.5 * x, y: 0.5 + 0.5 * y)
    }

    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let c = cos(angle)
        let s = sin(angle)
        return CGPoint(x: point.x * c - point.y * s,
                       y: point.x * s + point.y * c)
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = clamp((value - edge0) / max(edge1 - edge0, 0.0001), 0, 1)
        return t * t * (3 - 2 * t)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func multiply(_ color: FlyIORGB, _ amount: CGFloat) -> FlyIORGB {
        FlyIORGB(red: color.red * amount,
                 green: color.green * amount,
                 blue: color.blue * amount)
    }

    private func add(_ a: FlyIORGB, _ b: FlyIORGB) -> FlyIORGB {
        FlyIORGB(red: a.red + b.red,
                 green: a.green + b.green,
                 blue: a.blue + b.blue)
    }
}

private struct FlyIORGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}
