import Foundation

/// Runs every configured provider's `fetchDeployments()` in parallel with a
/// shared deadline. Extracted from `PollingManager` so the iOS background
/// refresh handler can reuse the exact same fetch logic under a tighter
/// deadline (BGAppRefreshTask gives us roughly 30 seconds).
public enum DeploymentFetcher {
    /// Per-provider outcome captured from a single fetch pass. `successes`
    /// only includes providers whose top-level fetch returned without
    /// throwing — providers that errored out (or hit the deadline) are
    /// reported in `errors` and **omitted** from `successes` so the caller
    /// can decide whether to merge with prior state or wipe the slot.
    public struct BatchResult {
        public let successes: [String: [Deployment]]
        public let errors: [(String, Error)]

        public init(successes: [String: [Deployment]], errors: [(String, Error)]) {
            self.successes = successes
            self.errors = errors
        }
    }

    /// Per-provider variant. Lets callers (`AppState`) keep last-known-good
    /// deployments for providers that errored on this pass — a rate-limited
    /// service no longer wipes its rows from the menu mid-poll.
    public static func fetchAllPerProvider(deadline: TimeInterval) async -> BatchResult {
        let providers = ServiceRegistry.shared.configuredProviders
        guard !providers.isEmpty else { return BatchResult(successes: [:], errors: []) }

        return await withTaskGroup(of: (String, Result<DeploymentFetchResult, Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let result = try await provider.fetchDeployments()
                        return (provider.id, .success(result))
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

            var successes: [String: [Deployment]] = [:]
            var errs: [(String, Error)] = []
            for await (providerID, result) in group {
                if providerID == "__deadline__" {
                    group.cancelAll()
                    await DiagnosticsLogger.shared.warning(
                        "Fetch deadline (\(Int(deadline))s) reached — slower providers dropped this pass",
                        category: "polling"
                    )
                    break
                }
                switch result {
                case .success(let fetchResult):
                    // Sort newest-first so callers that cap the list (the menu
                    // takes .prefix(5) per provider) interleave runs across
                    // projects/apps by recency instead of showing whichever
                    // project the API returned first.
                    successes[providerID] = fetchResult.deployments
                        .sorted { $0.createdAt > $1.createdAt }
                    if !fetchResult.itemErrors.isEmpty {
                        // Collapse per-entry failures into one provider-level
                        // error so existing sidebar/menu logic (keyed by
                        // provider ID) lights up. The Test button in Settings
                        // reaches past this and renders per-entry details
                        // directly from DeploymentFetchResult.
                        let summary = fetchResult.itemErrors
                            .map { "\($0.item): \($0.error.localizedDescription)" }
                            .joined(separator: "; ")
                        errs.append((providerID, ItemErrorSummary(message: summary)))
                        await DiagnosticsLogger.shared.warning(
                            "\(fetchResult.itemErrors.count) item(s) failed — \(summary)",
                            category: providerID
                        )
                    }
                case .failure(let error):
                    errs.append((providerID, error))
                    await DiagnosticsLogger.shared.error(
                        "Fetch failed: \(error.localizedDescription)",
                        category: providerID
                    )
                }
            }
            return BatchResult(successes: successes, errors: errs)
        }
    }

    /// Flat-list variant kept for callers (iOS background refresh, widget
    /// timeline) that don't need per-provider granularity.
    public static func fetchAll(deadline: TimeInterval) async
        -> (deployments: [Deployment], errors: [(String, Error)])
    {
        let batch = await fetchAllPerProvider(deadline: deadline)
        let flat = batch.successes
            .values
            .flatMap { $0 }
            .sorted { $0.createdAt > $1.createdAt }
        return (flat, batch.errors)
    }
}

/// Wraps a combined per-entry error message so `AppState.errors` (keyed by
/// provider ID and holding `localizedDescription` strings) can render it.
private struct ItemErrorSummary: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

extension DeploymentFetchResult {
    /// Fan out an async fetch over a list of items, collecting successes into
    /// `deployments` and per-item failures into `itemErrors`. A single bad
    /// item does not prevent the others from completing.
    public static func collecting<Item>(
        _ items: [Item],
        name: @escaping (Item) -> String,
        fetch: @escaping (Item) async throws -> [Deployment]
    ) async -> DeploymentFetchResult {
        await withTaskGroup(of: (String, Result<[Deployment], Error>).self) { group in
            for item in items {
                let label = name(item)
                group.addTask {
                    do { return (label, .success(try await fetch(item))) }
                    catch { return (label, .failure(error)) }
                }
            }
            var deployments: [Deployment] = []
            var errors: [(item: String, error: Error)] = []
            for await (label, result) in group {
                switch result {
                case .success(let d): deployments.append(contentsOf: d)
                case .failure(let e): errors.append((item: label, error: e))
                }
            }
            return DeploymentFetchResult(deployments: deployments, itemErrors: errors)
        }
    }
}
