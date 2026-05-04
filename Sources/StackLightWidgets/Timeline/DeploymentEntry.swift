import Foundation
import StackLightCore
import WidgetKit

/// Timeline entry rendered by every `DeploymentsWidget` family.
struct DeploymentEntry: TimelineEntry {
    let date: Date
    let deployments: [Deployment]
    let activeBuild: Bool
    let writtenAt: Date?
    let configuration: DeploymentWidgetIntent

    static func placeholder(for configuration: DeploymentWidgetIntent) -> DeploymentEntry {
        DeploymentEntry(
            date: Date(),
            deployments: DeploymentEntry.sampleDeployments,
            activeBuild: true,
            writtenAt: Date(),
            configuration: configuration
        )
    }

    static let sampleDeployments: [Deployment] = [
        Deployment(
            id: "sample-1",
            providerID: "vercel",
            projectName: "marketing-site",
            status: .success,
            url: URL(string: "https://vercel.com"),
            createdAt: Date().addingTimeInterval(-120),
            commitMessage: "Update landing copy",
            branch: "main"
        ),
        Deployment(
            id: "sample-2",
            providerID: "cloudflare",
            projectName: "docs",
            status: .building,
            url: URL(string: "https://cloudflare.com"),
            createdAt: Date().addingTimeInterval(-30),
            commitMessage: "Rework nav",
            branch: "feat/nav"
        ),
        Deployment(
            id: "sample-3",
            providerID: "githubActions",
            projectName: "stacklight",
            status: .failed,
            url: nil,
            createdAt: Date().addingTimeInterval(-900),
            commitMessage: "Fix broken build",
            branch: "fix/build"
        )
    ]
}
