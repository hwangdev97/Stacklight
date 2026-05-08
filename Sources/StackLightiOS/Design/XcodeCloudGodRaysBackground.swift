import SwiftUI

struct XcodeCloudGodRaysBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                XcodeCloudGodRaysField(phase: phase, cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.36),
                                .white.opacity(0.11),
                                Color(red: 0.25, green: 0.60, blue: 0.77).opacity(0.30)
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

private struct XcodeCloudGodRaysField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat

    private let colorBack = XcodeCloudRGB(red: 0.251, green: 0.604, blue: 0.769) // #409ac4
    private let colorBloom = XcodeCloudRGB(red: 0, green: 0, blue: 0)
    private let rayColors = [
        XcodeCloudRGBA(red: 1, green: 1, blue: 1, alpha: 0.431), // #ffffff6e
        XcodeCloudRGBA(red: 0.961, green: 0.961, blue: 1, alpha: 0.941) // #f5f5fff0
    ]

    private let bloom: CGFloat = 0.4
    private let intensity: CGFloat = 0.8
    private let density: CGFloat = 0.16
    private let spotty: CGFloat = 0.4
    private let midSize: CGFloat = 0.55
    private let midIntensity: CGFloat = 0.54
    private let speed: CGFloat = 1.11
    private let scale: CGFloat = 0.92
    private let offsetX: CGFloat = 0.42
    private let offsetY: CGFloat = -1

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            let sample: CGFloat = 2
            let t = 0.2 * CGFloat(phase) * speed
            let aspect = size.width / max(size.height, 1)

            for y in stride(from: CGFloat.zero, to: size.height, by: sample) {
                for x in stride(from: CGFloat.zero, to: size.width, by: sample) {
                    let normalized = CGPoint(x: (x + sample * 0.5) / max(size.width, 1),
                                             y: (y + sample * 0.5) / max(size.height, 1))
                    var shapeUV = CGPoint(x: (normalized.x - 0.5) * aspect,
                                          y: normalized.y - 0.5)
                    shapeUV.x -= offsetX
                    shapeUV.y += offsetY
                    shapeUV.x /= scale
                    shapeUV.y /= scale

                    let radius = hypot(shapeUV.x, shapeUV.y)
                    let spots = 6.5 * abs(spotty)
                    let rayIntensity = 4 - 3 * clamp(intensity, 0, 1)

                    let mid = 10 * abs(midSize)
                    let middleShapeLow = 0.02 * mid
                    let middleShapeHigh = max(mid, 0.0001)
                    var middleShape = pow(midIntensity, 0.3) * (1 - smoothstep(middleShapeLow, middleShapeHigh, 3 * radius))
                    middleShape = pow(max(middleShape, 0), 5)

                    var accumColor = XcodeCloudRGB(red: 0, green: 0, blue: 0)
                    var accumAlpha: CGFloat = 0

                    for index in rayColors.indices {
                        let i = CGFloat(index)
                        let rotatedUV = rotate(shapeUV, by: i + 1)
                        let r1 = radius * (1 + 0.4 * i) - 3 * t
                        let r2 = 0.5 * radius * (1 + spots) - 2 * t
                        let densityValue = 6 * density + step(0.5, density) * pow(4.5 * (density - 0.5), 4)
                        let frequency = mix(1, 3 + 0.5 * i, hash(i * 15)) * densityValue

                        var ray = raysShape(rotatedUV, r1, 5 * frequency, rayIntensity)
                        ray *= raysShape(rotatedUV, r2, 4 * frequency, rayIntensity)
                        ray += (1 + 4 * ray) * middleShape
                        ray = clamp(ray, 0, 1)

                        let sourceAlpha = rayColors[index].alpha * ray
                        let sourceColor = multiply(rayColors[index].rgb, sourceAlpha)

                        let alphaBlendColor = add(accumColor, multiply(sourceColor, 1 - accumAlpha))
                        let alphaBlendAlpha = accumAlpha + (1 - accumAlpha) * sourceAlpha
                        let addBlendColor = add(accumColor, sourceColor)
                        let addBlendAlpha = accumAlpha + sourceAlpha

                        accumColor = mix(alphaBlendColor, addBlendColor, bloom)
                        accumAlpha = mix(alphaBlendAlpha, addBlendAlpha, bloom)
                    }

                    let overlayAlpha: CGFloat = 1
                    let overlayColor = multiply(colorBloom, overlayAlpha)
                    let colorWithOverlay = add(accumColor, multiply(overlayColor, accumAlpha))
                    accumColor = mix(accumColor, colorWithOverlay, bloom)

                    var rgb = add(accumColor, multiply(colorBack, 1 - accumAlpha))
                    let bandingDither = (hash(CGPoint(x: x + CGFloat(phase) * 2.5, y: y)) - 0.5) / 255
                    rgb = XcodeCloudRGB(
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

    private func raysShape(_ uv: CGPoint, _ radiusOffset: CGFloat, _ frequency: CGFloat, _ rayIntensity: CGFloat) -> CGFloat {
        let angle = atan2(uv.y, uv.x)
        let left = CGPoint(x: angle * frequency, y: radiusOffset)
        let right = CGPoint(x: fract(angle / (2 * .pi)) * 2 * .pi * frequency, y: radiusOffset)
        let leftNoise = pow(max(valueNoise(left), 0), rayIntensity)
        let rightNoise = pow(max(valueNoise(right), 0), rayIntensity)
        return mix(rightNoise, leftNoise, smoothstep(-0.15, 0.15, uv.x))
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
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y)
    }

    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let c = cos(angle)
        let s = sin(angle)
        return CGPoint(x: point.x * c - point.y * s,
                       y: point.x * s + point.y * c)
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

    private func step(_ edge: CGFloat, _ value: CGFloat) -> CGFloat {
        value < edge ? 0 : 1
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = clamp((value - edge0) / max(edge1 - edge0, 0.0001), 0, 1)
        return t * t * (3 - 2 * t)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * clamp(t, 0, 1)
    }

    private func mix(_ a: XcodeCloudRGB, _ b: XcodeCloudRGB, _ t: CGFloat) -> XcodeCloudRGB {
        XcodeCloudRGB(
            red: mix(a.red, b.red, t),
            green: mix(a.green, b.green, t),
            blue: mix(a.blue, b.blue, t)
        )
    }

    private func multiply(_ color: XcodeCloudRGB, _ amount: CGFloat) -> XcodeCloudRGB {
        XcodeCloudRGB(red: color.red * amount,
                      green: color.green * amount,
                      blue: color.blue * amount)
    }

    private func add(_ a: XcodeCloudRGB, _ b: XcodeCloudRGB) -> XcodeCloudRGB {
        XcodeCloudRGB(red: a.red + b.red,
                      green: a.green + b.green,
                      blue: a.blue + b.blue)
    }
}

private struct XcodeCloudRGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}

private struct XcodeCloudRGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var rgb: XcodeCloudRGB {
        XcodeCloudRGB(red: red, green: green, blue: blue)
    }
}
