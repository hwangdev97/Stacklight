import SwiftUI

/// A full-bleed coloured-shader view that renders the per-provider "light"
/// sitting behind Liquid Glass. This is the low-level rendering primitive
/// used by `GlowBackground`. Callers should rarely use it directly.
struct ProviderShaderView: View {
    let kind: ProviderTheme.ShaderKind
    let tint: Color
    let accent: Color
    let glow: Color
    var statusAccent: Color? = nil
    var intensity: CGFloat = 1.0
    var animated: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation(minimumInterval: animated ? 1.0/30.0 : nil,
                                    paused: !animated)) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate
                              .truncatingRemainder(dividingBy: 1_000))
                Rectangle()
                    .colorEffect(
                        shader(size: size, time: t)
                    )
                    .drawingGroup(opaque: false)
            }
        }
        .allowsHitTesting(false)
    }

    private func shader(size: CGSize, time: Float) -> Shader {
        let function = ShaderFunction(library: .default, name: functionName(for: kind))
        let status = statusAccent ?? Color.clear
        let statusVec = Shader.Argument.color(status)
        return Shader(function: function, arguments: [
            .float2(Float(size.width), Float(size.height)),
            .float(time),
            .color(tint),
            .color(accent),
            .color(glow),
            statusVec,
            .float(Float(intensity))
        ])
    }

    private func functionName(for kind: ProviderTheme.ShaderKind) -> String {
        switch kind {
        case .monoBeam:      return "monoBeam"
        case .softBlobs:     return "softBlobs"
        case .gearShimmer:   return "gearShimmer"
        case .diffStreaks:   return "diffStreaks"
        case .rippleField:   return "rippleField"
        case .motionStreaks: return "motionStreaks"
        case .vaporTrail:    return "vaporTrail"
        case .depthClouds:   return "depthClouds"
        case .sweepWing:     return "sweepWing"
        case .errorAura:     return "errorAura"
        case .neutral:       return "neutral"
        case .pixelBeams:    return "pixelBeams"
        }
    }
}

// MARK: - Specialised shader views

/// Renders the `statusOrb` shader. Used by `StatusOrb`.
struct StatusOrbShaderView: View {
    let color: Color
    var pulse: CGFloat = 0.6

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate
                              .truncatingRemainder(dividingBy: 1_000))
                Rectangle()
                    .colorEffect(
                        Shader(
                            function: .init(library: .default, name: "statusOrb"),
                            arguments: [
                                .float2(Float(size.width), Float(size.height)),
                                .float(t),
                                .color(color),
                                .float(Float(pulse))
                            ])
                    )
                    .drawingGroup(opaque: false)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Renders the `liquidDroplet` shader. Used by `LiquidRefreshIndicator`.
struct LiquidDropletShaderView: View {
    let color: Color
    let stretch: CGFloat   // 1.0 = sphere, 2.5 = stretched droplet
    let intensity: CGFloat // alpha multiplier

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate
                              .truncatingRemainder(dividingBy: 1_000))
                Rectangle()
                    .colorEffect(
                        Shader(
                            function: .init(library: .default, name: "liquidDroplet"),
                            arguments: [
                                .float2(Float(size.width), Float(size.height)),
                                .float(t),
                                .color(color),
                                .float(Float(stretch)),
                                .float(Float(intensity))
                            ])
                    )
                    .drawingGroup(opaque: false)
            }
        }
        .allowsHitTesting(false)
    }
}
