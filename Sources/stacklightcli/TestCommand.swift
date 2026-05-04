import ArgumentParser
import Foundation
import StackLightCore

struct TestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run a single fetch against one provider — useful for verifying credentials."
    )

    @Argument(help: "Provider ID (e.g. vercel, cloudflare, githubActions).")
    var providerID: String

    @OptionGroup
    var output: OutputOptions

    func run() async throws {
        guard let provider = CLIContext.provider(named: providerID) else {
            exitWithError("unknown provider '\(providerID)'. Try `stacklight providers list`.")
        }
        guard provider.isConfigured else {
            exitWithError("provider '\(providerID)' has no credentials configured. Open Settings → \(provider.displayName).")
        }

        let started = Date()
        do {
            let result = try await provider.fetchDeployments()
            let elapsed = Date().timeIntervalSince(started)

            switch output.format {
            case .json:
                struct Payload: Encodable {
                    let providerID: String
                    let elapsedSeconds: Double
                    let deployments: [DeploymentRecord]
                    let itemErrors: [ItemErrorRecord]
                }
                struct ItemErrorRecord: Encodable {
                    let item: String
                    let message: String
                }
                try printJSON(Payload(
                    providerID: providerID,
                    elapsedSeconds: elapsed,
                    deployments: result.deployments.map(DeploymentRecord.init),
                    itemErrors: result.itemErrors.map {
                        ItemErrorRecord(item: $0.item, message: $0.error.localizedDescription)
                    }
                ))
            case .plain:
                print("✓ \(provider.displayName) (\(String(format: "%.2f", elapsed))s)")
                print("  \(result.deployments.count) deployments fetched")
                if !result.itemErrors.isEmpty {
                    print("  partial failures:")
                    for entry in result.itemErrors {
                        print("    - \(entry.item): \(entry.error.localizedDescription)")
                    }
                }
                for deployment in result.deployments.prefix(5) {
                    print("    \(deployment.status.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(deployment.projectName) (\(deployment.relativeTime))")
                }
            }
        } catch {
            switch output.format {
            case .json:
                struct ErrorPayload: Encodable {
                    let providerID: String
                    let error: String
                }
                try printJSON(ErrorPayload(providerID: providerID, error: error.localizedDescription))
            case .plain:
                printError("\(provider.displayName) fetch failed: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }
    }
}
