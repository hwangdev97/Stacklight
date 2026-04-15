import SwiftUI

/// The signature backdrop for every provider-bearing surface in the app.
///
/// Layer stack (bottom → top):
///   1. Deep card tint (so the glow has something dense to bloom against)
///   2. Animated Metal shader (`ProviderShader`) — the actual colored "light"
///   3. Soft gaussian blur via `.blur()` to smear the shader (giving the
///      volumetric out-of-focus feel seen in the reference image)
///   4. A subtle inner-highlight at the top edge to sell the glass curvature
///   5. Liquid Glass overlay frosting everything above into a readable surface
///   6. Hairline stroke
///
/// The whole stack is clipped to the passed shape so it composes cleanly as
/// the background of any card / tile / hero.
struct GlowBackground<S: Shape>: View {
    let theme: ProviderTheme
    let shape: S
    var statusAccent: Color? = nil
    var intensity: CGFloat = 1.0
    var animated: Bool = true

    var body: some View {
        shape
            .fill(theme.tint)
            .overlay {
                if !DesignTokens.Motion.reduceTransparency {
                    ProviderShaderView(
                        kind: theme.shader,
                        tint: theme.tint,
                        accent: theme.accent,
                        glow: theme.glow,
                        statusAccent: statusAccent,
                        intensity: intensity,
                        animated: animated && !DesignTokens.Motion.reduceMotion
                    )
                    .blur(radius: 22)
                    .opacity(0.95)
                }
            }
            .overlay {
                // Inner top highlight — sells the "glass bowl" curvature.
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.00),
                                Color.white.opacity(0.00),
                                Color.white.opacity(0.10),
                            ],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 1.2)
                    .blendMode(.plusLighter)
            }
            .clipShape(shape)
            .overlay {
                // Delicate hairline to define the card edge against the dark bg.
                shape.stroke(DesignTokens.Palette.hairline, lineWidth: 0.5)
            }
    }
}
