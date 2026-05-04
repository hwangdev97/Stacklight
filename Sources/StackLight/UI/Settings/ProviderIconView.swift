import SwiftUI
import StackLightCore

/// Small rounded-square icon for a deployment provider. Uses the provider's
/// custom asset if available, otherwise falls back to an SF Symbol.
struct ProviderIconView: View {
    let provider: DeploymentProvider
    var size: CGFloat = 24
    var iconSize: CGFloat? = nil
    var cornerRadius: CGFloat? = nil
    var color: Color? = nil

    var body: some View {
        let radius = cornerRadius ?? size * 0.5
        let innerSize = iconSize ?? size * 0.5
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let tint: Color = color ?? provider.color
        Group {
            if let asset = provider.iconAsset {
                Image(asset)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: innerSize, height: innerSize)
            } else {
                Image(systemName: provider.iconSymbol)
                    .font(.system(size: innerSize, weight: .medium))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(tint.gradient)
        .overlay(
            LinearGradient(
                colors: [.white.opacity(0.5), .white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
            .mask(shape.stroke(lineWidth: 1.5))
        )
        .clipShape(shape)
    }
}

/// Large "hero" icon used at the top of a detail page. Brand color fills the
/// outer tile; the glyph sits on a frosted-glass chip for a Liquid Glass feel.
struct GlassDetailIcon: View {
    let color: Color
    var systemImage: String? = nil
    var asset: String? = nil
    var tileSize: CGFloat = 72
    var chipSize: CGFloat = 48
    var iconSize: CGFloat = 26
    var outerCornerRadius: CGFloat = 20
    var innerCornerRadius: CGFloat = 14

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)

        ZStack {
            outer.fill(color.gradient)
                .frame(width: tileSize, height: tileSize)
            inner
                .fill(color.gradient)
                .overlay(inner.strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .overlay {
                    glyph
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                    
                }
                
                .frame(width: tileSize, height: tileSize)
        }
        .frame(width: tileSize, height: tileSize)
        .overlay(
            LinearGradient(
                colors: [.white.opacity(0.5), .white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
            .mask(outer.stroke(lineWidth: 1.5))
        )
        .clipShape(outer)
    }

    @ViewBuilder
    private var glyph: some View {
        if let asset {
            Image(asset)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize , height: iconSize )
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .frame(width: iconSize + 32, height: iconSize + 32)
        }
    }
}
