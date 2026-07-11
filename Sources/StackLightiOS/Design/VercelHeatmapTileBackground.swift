import SwiftUI

struct VercelHeatmapTileBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        GlowBackground(
            theme: .forProviderID("vercel"),
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
