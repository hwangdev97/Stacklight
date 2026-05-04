import SwiftUI
import StackLightCore
import WidgetKit

/// `.systemExtraLarge` — iPad-only Home Screen size. Renders up to 12 rows
/// in a two-column layout with a header and a last-refresh footer.
struct ExtraLargeDeploymentView: View {
    let entry: DeploymentEntry

    private var rows: [Deployment] {
        Array(entry.deployments.prefix(12))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack {
            background
            if rows.isEmpty {
                EmptyStateView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(rows) { deployment in
                            Link(destination: SmallDeploymentView.deepLink(for: deployment)
                                 ?? URL(string: "stacklight://home")!) {
                                DeploymentRow(deployment: deployment, now: entry.date)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    footer
                }
                .padding(16)
            }
        }
        .containerBackground(for: .widget) { background }
    }

    private var header: some View {
        HStack {
            Text("StackLight")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if entry.activeBuild {
                HStack(spacing: 4) {
                    Circle()
                        .fill(WidgetPalette.building)
                        .frame(width: 6, height: 6)
                    Text("Building")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.08)))
            }
            Text("\(entry.deployments.count) tracked")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let writtenAt = entry.writtenAt {
            Text("Updated \(WidgetFormatters.relativeString(for: writtenAt, now: entry.date))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [WidgetPalette.background, WidgetPalette.surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
