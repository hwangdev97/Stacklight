import AppIntents
import StackLightCore
import WidgetKit

/// User-facing configuration for the StackLight widget. Lets the user filter
/// by provider, pin a specific project, or hide everything except active
/// builds.
struct DeploymentWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "StackLight Widget"
    static var description = IntentDescription("Show deployment status from your configured providers.")

    @Parameter(title: "Provider", default: ProviderEntity.any)
    var provider: ProviderEntity?

    @Parameter(title: "Pinned Project")
    var pinnedProject: ProjectEntity?

    @Parameter(title: "Only Active Builds", default: false)
    var activeOnly: Bool

    init() {}

    init(provider: ProviderEntity? = nil,
         pinnedProject: ProjectEntity? = nil,
         activeOnly: Bool = false) {
        self.provider = provider
        self.pinnedProject = pinnedProject
        self.activeOnly = activeOnly
    }
}
