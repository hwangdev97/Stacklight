import SwiftUI

struct CloudflareGrainGradientBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                GrainGradientCornersField(phase: phase, cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34),
                                .white.opacity(0.10),
                                Color(red: 1.0, green: 0.30, blue: 0.0).opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct GrainGradientCornersField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let t = CGFloat(0.1 * (phase + 7.0))
            let aspect = size.width / max(size.height, 1)
            let sample: CGFloat = 2

            for y in stride(from: CGFloat.zero, to: size.height, by: sample) {
                for x in stride(from: CGFloat.zero, to: size.width, by: sample) {
                    let uv = CGPoint(x: (x + sample * 0.5) / max(size.width, 1),
                                     y: (y + sample * 0.5) / max(size.height, 1))
                    let p = CGPoint(x: (uv.x - 0.5) * aspect, y: uv.y - 0.5)
                    let grainUV = CGPoint(x: p.x * size.width * 0.7,
                                          y: p.y * size.height * 0.7)
                    let n0 = valueNoise(CGPoint(x: grainUV.x * 0.018 + t * 0.6,
                                                y: grainUV.y * 0.018 - t * 0.35))
                    let n1 = fbm(CGPoint(x: grainUV.x * 0.008 - t * 0.7,
                                         y: grainUV.y * 0.008 - t * 0.25))
                    let grainDist = (n0 - 0.5) * 0.34 - (n1 - 0.5) * 0.22

                    let lowerLine = p.y + 0.30 + 0.34 * p.x + grainDist + 0.035 * sin(3.0 * t)
                    let upperLine = p.y - 0.24 + 0.24 * p.x - grainDist - 0.030 * cos(5.25 * t)
                    let lowerSheet = exp(-pow(lowerLine * 4.3, 2.0)) * (1.0 - smoothstep(-0.20, 0.68, uv.x))
                    let upperSheet = exp(-pow(upperLine * 4.0, 2.0)) * smoothstep(0.28, 0.95, uv.x)
                    let cornerA = 0.35 * (1.0 - smoothstep(0.10, 0.95, distance(p, CGPoint(x: -0.54 * aspect, y: 0.56))))
                    let cornerB = 0.42 * (1.0 - smoothstep(0.08, 1.05, distance(p, CGPoint(x: 0.52 * aspect, y: -0.54))))
                    var shape = clamp(lowerSheet + upperSheet + cornerA + cornerB + 0.10 * (n0 - 0.5), 0, 1)

                    let baseWarmth = smoothstep(0.0, 1.0, uv.x * 0.8 + (1.0 - uv.y) * 0.2)
                    let back = mix((1.00, 0.28, 0.00), (1.00, 0.44, 0.00), baseWarmth)
                    var rgb = mix(back, (1.00, 0.56, 0.38), smoothstep(0.05, 0.42, shape))
                    rgb = mix(rgb, (1.00, 0.97, 0.64), smoothstep(0.32, 0.68, shape))
                    rgb = mix(rgb, (1.00, 0.99, 0.98), smoothstep(0.58, 0.95, shape))
                    rgb = mix(rgb, (1.00, 0.28, 0.00), 0.26 * smoothstep(0.20, 0.75, n1) * (1.0 - shape))

                    let grain = hash(CGPoint(x: x * 1.73, y: y * 1.73))
                    let lift = (grain - 0.5) * 0.028
                    rgb = (clamp(rgb.0 + lift, 0, 1),
                           clamp(rgb.1 + lift, 0, 1),
                           clamp(rgb.2 + lift, 0, 1))

                    shape = smoothstep(0, 1, shape)
                    _ = shape
                    let cell = CGRect(x: x, y: y, width: sample + 0.5, height: sample + 0.5)
                    context.fill(Path(cell), with: .color(Color(red: rgb.0, green: rgb.1, blue: rgb.2)))
                }
            }

            let noiseStep: CGFloat = 4
            for y in stride(from: CGFloat.zero, through: size.height, by: noiseStep) {
                for x in stride(from: CGFloat.zero, through: size.width, by: noiseStep) {
                    let n = fract(sin((x + CGFloat(phase) * 3.0) * 12.9898 + y * 78.233) * 43758.5453)
                    let alpha = 0.020 + 0.060 * n
                    let dot = CGRect(x: x, y: y, width: 0.85, height: 0.85)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(alpha)))
                }
            }
        }
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }

    private func hash(_ point: CGPoint) -> CGFloat {
        fract(sin(point.x * 12.9898 + point.y * 78.233) * 43758.5453)
    }

    private func valueNoise(_ point: CGPoint) -> CGFloat {
        let cell = CGPoint(x: floor(point.x), y: floor(point.y))
        let f = CGPoint(x: fract(point.x), y: fract(point.y))
        let u = CGPoint(x: f.x * f.x * (3 - 2 * f.x),
                        y: f.y * f.y * (3 - 2 * f.y))
        let a = hash(cell)
        let b = hash(CGPoint(x: cell.x + 1, y: cell.y))
        let c = hash(CGPoint(x: cell.x, y: cell.y + 1))
        let d = hash(CGPoint(x: cell.x + 1, y: cell.y + 1))
        return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y)
    }

    private func fbm(_ point: CGPoint) -> CGFloat {
        var total: CGFloat = 0
        var amplitude: CGFloat = 0.5
        var p = point
        for _ in 0..<3 {
            total += valueNoise(p) * amplitude
            p = CGPoint(x: p.x * 1.99 + 17.1, y: p.y * 1.99 - 9.4)
            amplitude *= 0.55
        }
        return clamp(total, 0, 1)
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = clamp((value - edge0) / max(edge1 - edge0, 0.0001), 0, 1)
        return t * t * (3 - 2 * t)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func mix(_ a: (CGFloat, CGFloat, CGFloat),
                     _ b: (CGFloat, CGFloat, CGFloat),
                     _ t: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let amount = clamp(t, 0, 1)
        return (
            lerp(a.0, b.0, amount),
            lerp(a.1, b.1, amount),
            lerp(a.2, b.2, amount)
        )
    }
}
