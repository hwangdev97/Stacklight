import Foundation

/// Runs every configured provider's `fetchDeployments()` in parallel with a
/// shared deadline. Extracted from `PollingManager` so the iOS background
/// refresh handler can reuse the exact same fetch logic under a tighter
/// deadline (BGAppRefreshTask gives us roughly 30 seconds).
enum DeploymentFetcher {
    static func fetchAll(deadline: TimeInterval) async
        -> (deployments: [Deployment], errors: [(String, Error)])
    {
        let providers = ServiceRegistry.shared.configuredProviders
        guard !providers.isEmpty else { return ([], []) }

        return await withTaskGroup(of: (String, Result<[Deployment], Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let deployments = try await provider.fetchDeployments()
                        return (provider.id, .success(deployments))
                    } catch {
                        return (provider.id, .failure(error))
                    }
                }
            }
            // Deadline sentinel — first to win either caps total wall time or
            // lets every provider finish naturally.
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
                return ("__deadline__", .failure(CancellationError()))
            }

            var all: [Deployment] = []
            var errs: [(String, Error)] = []
            for await (providerID, result) in group {
                if providerID == "__deadline__" {
                    group.cancelAll()
                    break
                }
                switch result {
                case .success(let deployments): all.append(contentsOf: deployments)
                case .failure(let error):       errs.append((providerID, error))
                }
            }
            return (all.sorted { $0.createdAt > $1.createdAt }, errs)
        }
    }
}
