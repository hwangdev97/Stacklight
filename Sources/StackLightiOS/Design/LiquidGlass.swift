import SwiftUI
import StackLightCore

/// Lightweight surface styles used throughout the iOS UI.
///
/// The names are kept so call sites remain readable, but these implementations
/// intentionally avoid Liquid Glass and translucent materials. Repeating those
/// effects throughout scrolling content forces costly offscreen compositing.
extension View {
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        self
            .background(DesignTokens.Palette.surface.opacity(0.98), in: shape)
            .overlay(shape.stroke(DesignTokens.Palette.hairline, lineWidth: 1))
    }

    func liquidGlassChip(in shape: Capsule = Capsule()) -> some View {
        self
            .background(Color.white.opacity(0.10), in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    func liquidGlassCircle() -> some View {
        self
            .background(Color.white.opacity(0.10), in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

/// Compatibility wrapper retained after removing grouped glass rendering.
struct LiquidGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        content()
    }
}

/// A small surfaced chip showing an SF Symbol or provider asset.
struct GlassIconChip: View {
    let systemImage: String
    var asset: String? = nil
    var tint: Color = .white
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let asset {
                Image(asset)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.5, height: size * 0.5)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
            }
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .liquidGlassCircle()
    }
}

extension GlassIconChip {
    init(provider: DeploymentProvider, tint: Color = .white, size: CGFloat = 34) {
        self.init(systemImage: provider.iconSymbol,
                  asset: provider.iconAsset,
                  tint: tint,
                  size: size)
    }
}

/// A compact filter pill with an optional SF Symbol.
struct GlassPill: View {
    let systemImage: String?
    let title: String
    var isSelected: Bool = false
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(title)
                .font(DesignTokens.Typography.chipLabel)
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.white : tint.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                Capsule().fill(Color.white.opacity(0.14))
            }
        }
        .liquidGlassChip()
    }
}
