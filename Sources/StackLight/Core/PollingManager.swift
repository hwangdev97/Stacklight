import Foundation

@MainActor
final class PollingManager {
    private var timer: Timer?
    var pollInterval: TimeInterval = 60
    var onUpdate: (([Deployment]) -> Void)?
    var onError: ((String, Error) -> Void)?

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        poll()
    }

    private func poll() {
        let providers = ServiceRegistry.shared.configuredProviders
        guard !providers.isEmpty else { return }

        Task {
            let results = await withTaskGroup(of: (String, Result<[Deployment], Error>).self) { group in
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

                var allDeployments: [Deployment] = []
                for await (providerID, result) in group {
                    switch result {
                    case .success(let deployments):
                        allDeployments.append(contentsOf: deployments)
                    case .failure(let error):
                        self.onError?(providerID, error)
                    }
                }
                return allDeployments
            }

            let sorted = results.sorted { $0.createdAt > $1.createdAt }
            onUpdate?(sorted)
        }
    }
}
