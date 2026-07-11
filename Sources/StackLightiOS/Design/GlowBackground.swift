import SwiftUI

/// A static provider-coloured surface.
///
/// Static gradients preserve provider identity without keeping a display-linked
/// render loop alive for every visible card.
struct GlowBackground<S: Shape>: View {
    let theme: ProviderTheme
    let shape: S
    var statusAccent: Color? = nil
    var intensity: CGFloat = 1.0

    var body: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [
                        theme.tint.opacity(0.92),
                        theme.tint.opacity(0.62),
                        DesignTokens.Palette.surface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape.fill(
                    RadialGradient(
                        colors: [
                            (statusAccent ?? theme.accent)
                                .opacity(0.18 * min(max(intensity, 0), 1.2)),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
            }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .clipShape(shape)
            .allowsHitTesting(false)
    }
}
