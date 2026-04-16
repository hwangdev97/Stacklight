import SwiftUI

/// Small rounded-square icon for a deployment provider. Uses the provider's
/// custom asset if available, otherwise falls back to an SF Symbol.
struct ProviderIconView: View {
    let provider: DeploymentProvider
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        if let asset = provider.iconAsset {
            Image(asset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.6, height: size * 0.6)
                .frame(width: size, height: size)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            Image(systemName: provider.iconSymbol)
                .font(.system(size: size * 0.5))
                .frame(width: size, height: size)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
