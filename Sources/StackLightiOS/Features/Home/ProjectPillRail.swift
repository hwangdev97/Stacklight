import SwiftUI

/// Horizontally scrolling rail of Liquid Glass pills letting the user filter
/// the Home deployment stream. Analogous to the "Living room / Kitchen"
/// selector in the reference smart-home mockup.
///
/// The rail shows "All" first, then one pill per configured provider.
struct ProjectPillRail: View {
    /// `nil` = "All".
    @Binding var selectedProviderID: String?
    let providerIDs: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(for: nil, title: "All", systemImage: "square.stack.3d.up")

                ForEach(providerIDs, id: \.self) { id in
                    if let provider = ServiceRegistry.shared.provider(withID: id) {
                        pill(for: id,
                             title: provider.displayName,
                             systemImage: provider.iconSymbol)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
    }

    private func pill(for id: String?, title: String, systemImage: String) -> some View {
        let isSelected = selectedProviderID == id
        let tint = id.map { ProviderTheme.forProviderID($0).accent } ?? .white
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selectedProviderID = id
            }
        } label: {
            GlassPill(systemImage: systemImage, title: title,
                      isSelected: isSelected, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectPillRailPreviewWrapper: View {
    @State private var selected: String? = nil

    var body: some View {
        ProjectPillRail(
            selectedProviderID: $selected,
            providerIDs: ServiceRegistry.shared.providers.map(\.id)
        )
    }
}

#Preview {
    ProjectPillRailPreviewWrapper()
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Palette.background)
        .preferredColorScheme(.dark)
}
