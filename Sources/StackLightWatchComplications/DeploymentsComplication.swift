import WidgetKit
import StackLightCore
import SwiftUI

struct DeploymentsComplication: Widget {
    let kind: String = "StackLightWatchDeploymentsComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchDeploymentProvider()
        ) { entry in
            DeploymentsComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Deployments")
        .description("Latest deployment status from your StackLight providers.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

struct DeploymentsComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchDeploymentEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    ComplicationCircularView(entry: entry)
        case .accessoryCorner:      ComplicationCornerView(entry: entry)
        case .accessoryInline:      ComplicationInlineView(entry: entry)
        case .accessoryRectangular: ComplicationRectangularView(entry: entry)
        default:                    ComplicationCircularView(entry: entry)
        }
    }
}
