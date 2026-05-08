import SwiftUI

struct VercelHeatmapTileBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.reduceMotion ? nil : 1.0 / 24.0,
                                paused: DesignTokens.Motion.reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black)

                PaperHeatmapTriangleField(phase: phase, cornerRadius: cornerRadius)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.36),
                                .white.opacity(0.08),
                                .white.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PaperHeatmapTriangleField: View {
    let phase: TimeInterval
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                HeatmapStaticBase(cornerRadius: cornerRadius)
                HeatmapAnimatedField(phase: phase)

                LinearGradient(
                    colors: [
                        .black.opacity(0.26),
                        .clear,
                        .black.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(.black.opacity(0.16))
                        .frame(width: size.width * 1.15, height: 18 + CGFloat(index) * 4)
                        .blur(radius: 9)
                        .rotationEffect(.degrees(-25))
                        .offset(x: CGFloat(index - 1) * 30,
                                y: CGFloat(sin(phase * 0.72 + Double(index)) * 18))
                }
            }
            .drawingGroup(opaque: true)
        }
    }
}

private struct HeatmapStaticBase: View {
    let cornerRadius: CGFloat

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            context.fill(
                Path(roundedRect: rect, cornerRadius: cornerRadius),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.02, green: 0.03, blue: 0.12),
                        Color(red: 0.06, green: 0.16, blue: 0.42),
                        Color(red: 0.00, green: 0.00, blue: 0.00)
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.maxY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.minY)
                )
            )

            let noiseStep: CGFloat = 10
            for y in stride(from: CGFloat.zero, through: canvasSize.height, by: noiseStep) {
                for x in stride(from: CGFloat.zero, through: canvasSize.width, by: noiseStep) {
                    let n = fract(sin(x * 12.9898 + y * 78.233) * 43758.5453)
                    let alpha = 0.008 + 0.014 * n
                    let dot = CGRect(x: x, y: y, width: 1.0, height: 1.0)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(alpha)))
                }
            }
        }
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }
}

private struct HeatmapAnimatedField: View {
    let phase: TimeInterval

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, canvasSize in
            let center = CGPoint(x: canvasSize.width * 0.50, y: canvasSize.height * 0.49)
            let beat = CGFloat((sin(phase * 0.58) + 1.0) * 0.5)
            let drift = CGFloat(phase.truncatingRemainder(dividingBy: 1.0))

            drawTriangleHeat(in: &context, center: center, width: 184, height: 160,
                             color: Color(red: 0.07, green: 0.12, blue: 0.42).opacity(0.78),
                             blur: 18, lineWidth: 58, blendMode: .normal)
            drawTriangleHeat(in: &context, center: center, width: 136 + beat * 10, height: 120 + beat * 8,
                             color: Color(red: 0.18, green: 0.39, blue: 0.91).opacity(0.68),
                             blur: 14, lineWidth: 42, blendMode: .plusLighter)
            drawTriangleHeat(in: &context, center: center, width: 110, height: 96,
                             color: Color(red: 0.42, green: 0.84, blue: 1.00).opacity(0.56),
                             blur: 10, lineWidth: 30, blendMode: .plusLighter)
            drawTriangleHeat(in: &context, center: center, width: 88, height: 76,
                             color: Color(red: 1.00, green: 0.90, blue: 0.48).opacity(0.58),
                             blur: 7, lineWidth: 20, blendMode: .plusLighter)
            drawTriangleHeat(in: &context, center: center, width: 68, height: 60,
                             color: Color(red: 1.00, green: 0.42, blue: 0.04).opacity(0.66),
                             blur: 5, lineWidth: 15, blendMode: .plusLighter)
            drawTriangleHeat(in: &context, center: center, width: 48, height: 42,
                             color: Color(red: 1.00, green: 0.20, blue: 0.00).opacity(0.66),
                             blur: 4, lineWidth: 10, blendMode: .plusLighter)

            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                for index in 0..<2 {
                    let t = CGFloat((phase * 0.20 + Double(index) / 2.0).truncatingRemainder(dividingBy: 1.0))
                    let offset = (t - 0.5) * canvasSize.height * 2.0
                    let y = canvasSize.height * 0.5 + offset
                    let bandRect = CGRect(x: -canvasSize.width * 0.24 + drift * 16,
                                          y: y,
                                          width: canvasSize.width * 1.50,
                                          height: 24 + CGFloat(index) * 5)
                    var band = Path(roundedRect: bandRect, cornerRadius: 22)
                    let rotation = CGAffineTransform(translationX: -center.x, y: -center.y)
                        .rotated(by: -.pi / 7.2)
                        .translatedBy(x: center.x, y: center.y)
                    band = band.applying(rotation)
                    layer.addFilter(.blur(radius: 9 + CGFloat(index) * 1.5))
                    layer.fill(band, with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.10, green: 0.20, blue: 0.66).opacity(0.00),
                            Color(red: 0.42, green: 0.84, blue: 1.00).opacity(0.26),
                            Color(red: 1.00, green: 0.90, blue: 0.48).opacity(0.34),
                            Color(red: 1.00, green: 0.30, blue: 0.00).opacity(0.48),
                            Color(red: 0.10, green: 0.20, blue: 0.66).opacity(0.00)
                        ]),
                        startPoint: bandRect.origin,
                        endPoint: CGPoint(x: bandRect.maxX, y: bandRect.maxY)
                    ))
                }
            }
        }
    }

    private func drawTriangleHeat(in context: inout GraphicsContext,
                                  center: CGPoint,
                                  width: CGFloat,
                                  height: CGFloat,
                                  color: Color,
                                  blur: CGFloat,
                                  lineWidth: CGFloat,
                                  blendMode: GraphicsContext.BlendMode) {
        context.drawLayer { layer in
            layer.blendMode = blendMode
            layer.addFilter(.blur(radius: blur))
            layer.stroke(trianglePath(center: center, width: width, height: height),
                         with: .color(color),
                         lineWidth: lineWidth)
        }
    }

    private func trianglePath(center: CGPoint, width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - height * 0.56))
        path.addLine(to: CGPoint(x: center.x + width * 0.50, y: center.y + height * 0.44))
        path.addLine(to: CGPoint(x: center.x - width * 0.50, y: center.y + height * 0.44))
        path.closeSubpath()
        return path
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }
}
