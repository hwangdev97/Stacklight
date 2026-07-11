import SwiftUI

struct XcodeCloudGodRaysBackground: View {
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    var body: some View {
        GlowBackground(
            theme: .forProviderID("xcodeCloud"),
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
