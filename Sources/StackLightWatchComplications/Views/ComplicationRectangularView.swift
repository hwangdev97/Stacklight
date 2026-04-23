import SwiftUI
import WidgetKit

struct ComplicationRectangularView: View {
    let entry: WatchDeploymentEntry

    var body: some View {
        let deployment = entry.deployments.first
        VStack(alignment: .leading, spacing: 1) {
            if let deployment {
                HStack(spacing: 4) {
                    Image(systemName: WidgetPalette.providerSymbol(for: deployment.providerID))
                        .font(.system(size: 11, weight: .semibold))
                    Text(deployment.projectName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                Text("\(deployment.status.displayName) · \(WidgetFormatters.relativeString(for: deployment.createdAt, now: entry.date))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
                if entry.deployments.count > 1 {
                    Text("+\(entry.deployments.count - 1) more")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("StackLight")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("No deployments")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}
