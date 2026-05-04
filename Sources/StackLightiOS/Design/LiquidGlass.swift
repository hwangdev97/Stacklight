import SwiftUI
import StackLightCore

/// Thin wrappers around iOS 26's native Liquid Glass APIs so the rest of the
/// app uses one consistent vocabulary. If we ever need to backport to iOS 25
/// or earlier, the fallbacks live here — everything else just calls
/// `.liquidGlass(...)` and friends.
extension View {
    /// Apply the regular Liquid Glass material clipped to the given shape.
    /// Suitable for cards and large surfaces.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(DesignTokens.Palette.hairline, lineWidth: 1))
        }
    }

    /// Clear/interactive Liquid Glass for small floating chips (status badge,
    /// power button, top-bar toolbar items).
    @ViewBuilder
    func liquidGlassChip(in shape: Capsule = Capsule()) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear.interactive(), in: shape)
        } else {
            self
                .background(.thinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    /// Circular glass chip — used for the little SF Symbol buttons that float
    /// on top of cards in the reference image.
    @ViewBuilder
    func liquidGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear.interactive(), in: Circle())
        } else {
            self
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }
}

/// Opt-in wrapper that groups adjacent glass shapes so their highlights merge
/// fluidly on scroll (iOS 26 behaviour). Falls back to a transparent group.
struct LiquidGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}

/// A small glass chip showing an SF Symbol. Matches the floating buttons in
/// the reference image (fan / heater / settings / power).
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

/// A glass pill with an SF Symbol + label — used for top-of-Home project
/// filters ("Living room / Kitchen" analogue).
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
