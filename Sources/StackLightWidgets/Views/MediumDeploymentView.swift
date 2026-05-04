import SwiftUI
import StackLightCore
import WidgetKit

/// `.systemMedium` — top 3 deployments as compact rows.
struct MediumDeploymentView: View {
    let entry: DeploymentEntry

    private var rows: [Deployment] {
        Array(entry.deployments.prefix(3))
    }

    var body: some View {
        ZStack {
            background
            if rows.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { deployment in
                        Link(destination: SmallDeploymentView.deepLink(for: deployment)
                             ?? URL(string: "stacklight://home")!) {
                            DeploymentRow(deployment: deployment, now: entry.date)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
        }
        .containerBackground(for: .widget) { background }
    }

    private var background: some View {
        LinearGradient(
            colors: [WidgetPalette.background, WidgetPalette.surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct DeploymentRow: View {
    let deployment: Deployment
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: WidgetPalette.providerSymbol(for: deployment.providerID))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetPalette.providerAccent(for: deployment.providerID))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(WidgetPalette.surface)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(deployment.projectName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(deployment.status.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetPalette.statusTint(for: deployment.status))
                    if let branch = deployment.branch {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.35))
                        Text(branch)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            Text(WidgetFormatters.relativeString(for: deployment.createdAt, now: now))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.65))
            WidgetStatusBadge(status: deployment.status, size: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }
}
