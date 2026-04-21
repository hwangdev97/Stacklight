import SwiftUI

/// Collapsible banner summarising per-provider refresh errors. Shared by the
/// compact `HomeView` and the regular-width `DeploymentGridView`.
struct HomeErrorBanner: View {
    let errors: [String: String]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                GlassIconChip(systemImage: "exclamationmark.triangle.fill",
                              tint: .white, size: 32)
                Text("Some services failed to refresh")
                    .font(DesignTokens.Typography.cardTitle)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .liquidGlassCircle()
                }
                .buttonStyle(.plain)
            }
            ForEach(errors.sorted(by: { $0.key < $1.key }), id: \.key) { providerID, message in
                let name = ServiceRegistry.shared.provider(withID: providerID)?.displayName ?? providerID
                Text("\(name): \(message)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            GlowBackground(
                theme: .error,
                shape: RoundedRectangle(cornerRadius: DesignTokens.Radius.md,
                                        style: .continuous),
                intensity: 0.9)
        )
    }
}
