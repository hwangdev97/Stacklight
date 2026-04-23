import WidgetKit
import Foundation

struct WatchDeploymentEntry: TimelineEntry {
    let date: Date
    let deployments: [Deployment]
    let activeBuild: Bool
    let writtenAt: Date?

    /// Aggregate status used to tint circular/corner complications. Priority:
    /// failed > building/queued > reviewing > success > unknown/empty.
    var rollupStatus: Deployment.Status {
        if deployments.isEmpty { return .unknown }
        if deployments.contains(where: { $0.status == .failed }) { return .failed }
        if deployments.contains(where: { $0.status == .building || $0.status == .queued }) { return .building }
        if deployments.contains(where: { $0.status == .reviewing }) { return .reviewing }
        if deployments.allSatisfy({ $0.status == .success }) { return .success }
        return .unknown
    }

    static func placeholder() -> WatchDeploymentEntry {
        WatchDeploymentEntry(
            date: Date(),
            deployments: [],
            activeBuild: false,
            writtenAt: nil
        )
    }
}
