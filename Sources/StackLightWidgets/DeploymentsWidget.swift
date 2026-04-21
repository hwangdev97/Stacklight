import WidgetKit
import SwiftUI

struct DeploymentsWidget: Widget {
    let kind: String = "StackLightDeploymentsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DeploymentWidgetIntent.self,
            provider: DeploymentTimelineProvider()
        ) { entry in
            DeploymentsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Deployments")
        .description("Glanceable deployment and build status from your configured providers.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct DeploymentsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeploymentEntry

    var body: some View {
        switch family {
        case .systemSmall:         SmallDeploymentView(entry: entry)
        case .systemMedium:        MediumDeploymentView(entry: entry)
        case .systemLarge:         LargeDeploymentView(entry: entry)
        case .systemExtraLarge:    ExtraLargeDeploymentView(entry: entry)
        case .accessoryCircular:   AccessoryCircularView(entry: entry)
        case .accessoryRectangular: AccessoryRectangularView(entry: entry)
        case .accessoryInline:     AccessoryInlineView(entry: entry)
        default:                   SmallDeploymentView(entry: entry)
        }
    }
}
