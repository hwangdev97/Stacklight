import SwiftUI

struct DeploymentRow: View {
    let deployment: Deployment

    var body: some View {
        HStack(spacing: 8) {
            WidgetStatusBadge(status: deployment.status, size: 10)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: WidgetPalette.providerSymbol(for: deployment.providerID))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetPalette.providerAccent(for: deployment.providerID))
                    Text(deployment.projectName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                Text("\(deployment.status.displayName) · \(WidgetFormatters.relativeString(for: deployment.createdAt))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
