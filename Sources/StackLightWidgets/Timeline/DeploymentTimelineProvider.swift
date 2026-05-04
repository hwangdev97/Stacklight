import Foundation
import StackLightCore
import WidgetKit
import AppIntents

/// Drives the widget's timeline. Reads the shared snapshot first for instant
/// render; falls back to a direct provider fetch if the snapshot is stale or
/// missing. Chooses a reload cadence based on whether any build is active so
/// we refresh fast during interesting moments without burning through iOS's
/// ~40–70 reloads/day budget.
struct DeploymentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = DeploymentEntry
    typealias Intent = DeploymentWidgetIntent

    /// Snapshot older than this triggers a live provider fetch.
    private let snapshotMaxAge: TimeInterval = 5 * 60
    /// Reload cadence while any deployment is building/queued.
    private let activeReloadInterval: TimeInterval = 60
    /// Reload cadence when everything is stable.
    private let stableReloadInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> DeploymentEntry {
        DeploymentEntry.placeholder(for: DeploymentWidgetIntent())
    }

    func snapshot(for configuration: DeploymentWidgetIntent,
                  in context: Context) async -> DeploymentEntry {
        let filtered = filterDeployments(currentDeployments(), using: configuration)
        return DeploymentEntry(
            date: Date(),
            deployments: filtered,
            activeBuild: filtered.contains { $0.status == .building || $0.status == .queued },
            writtenAt: SharedStore.read()?.writtenAt,
            configuration: configuration
        )
    }

    func timeline(for configuration: DeploymentWidgetIntent,
                  in context: Context) async -> Timeline<DeploymentEntry> {
        let now = Date()

        let (deployments, writtenAt) = await loadDeployments()
        let filtered = filterDeployments(deployments, using: configuration)
        let activeBuild = filtered.contains { $0.status == .building || $0.status == .queued }

        let reloadInterval = activeBuild ? activeReloadInterval : stableReloadInterval
        let stepCount = activeBuild ? 5 : 4

        var entries: [DeploymentEntry] = []
        for step in 0..<stepCount {
            let entryDate = now.addingTimeInterval(reloadInterval * Double(step))
            entries.append(DeploymentEntry(
                date: entryDate,
                deployments: filtered,
                activeBuild: activeBuild,
                writtenAt: writtenAt,
                configuration: configuration
            ))
        }

        let nextReload = now.addingTimeInterval(reloadInterval)
        return Timeline(entries: entries, policy: .after(nextReload))
    }

    // MARK: - Data loading

    private func currentDeployments() -> [Deployment] {
        SharedStore.read()?.deployments ?? []
    }

    /// Returns the freshest available set of deployments along with the
    /// snapshot write time (if the data came from the shared snapshot).
    private func loadDeployments() async -> ([Deployment], Date?) {
        let snapshot = SharedStore.read()
        if let snapshot, Date().timeIntervalSince(snapshot.writtenAt) < snapshotMaxAge {
            return (snapshot.deployments, snapshot.writtenAt)
        }

        let fetched = await fetchDirectly()
        if !fetched.isEmpty {
            SharedStore.write(deployments: fetched)
            return (fetched, Date())
        }
        // Fetch returned nothing (likely offline or unconfigured); fall back
        // to the (possibly stale) snapshot if we have one.
        return (snapshot?.deployments ?? [], snapshot?.writtenAt)
    }

    private func fetchDirectly() async -> [Deployment] {
        let providers = ServiceRegistry.shared.configuredProviders
        guard !providers.isEmpty else { return [] }

        return await withTaskGroup(of: [Deployment].self) { group in
            for provider in providers {
                group.addTask {
                    (try? await provider.fetchDeployments())?.deployments ?? []
                }
            }
            var all: [Deployment] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all.sorted { $0.createdAt > $1.createdAt }
        }
    }

    // MARK: - Filtering

    private func filterDeployments(_ deployments: [Deployment],
                                   using configuration: DeploymentWidgetIntent) -> [Deployment] {
        var result = deployments.sorted { $0.createdAt > $1.createdAt }
        if let providerID = configuration.provider?.id, providerID != ProviderEntity.anyID {
            result = result.filter { $0.providerID == providerID }
        }
        if let project = configuration.pinnedProject {
            result = result.filter {
                $0.providerID == project.providerID && $0.projectName == project.projectName
            }
        }
        if configuration.activeOnly {
            result = result.filter {
                $0.status == .building || $0.status == .queued || $0.status == .reviewing
            }
        }
        return result
    }
}
