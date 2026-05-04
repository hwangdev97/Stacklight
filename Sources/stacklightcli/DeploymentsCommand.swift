import ArgumentParser
import Foundation
import StackLightCore

struct DeploymentsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deployments",
        abstract: "List the latest deployments across configured providers."
    )

    @Option(name: .shortAndLong, help: "Restrict to a single provider (e.g. vercel, githubActions).")
    var provider: String?

    @Option(name: .long, help: "Hard wall-clock timeout (seconds) for the whole fetch.")
    var deadline: Double = 30

    @OptionGroup
    var output: OutputOptions

    func run() async throws {
        let (deployments, errors) = await DeploymentFetcher.fetchAll(deadline: deadline)
        let filtered: [Deployment] = {
            guard let provider else { return deployments }
            return deployments.filter { $0.providerID == provider }
        }()

        switch output.format {
        case .json:
            struct Payload: Encodable {
                let deployments: [DeploymentRecord]
                let errors: [ErrorRecord]
            }
            struct ErrorRecord: Encodable {
                let providerID: String
                let message: String
            }
            try printJSON(Payload(
                deployments: filtered.map(DeploymentRecord.init),
                errors: errors.map { ErrorRecord(providerID: $0.0, message: $0.1.localizedDescription) }
            ))
        case .plain:
            if filtered.isEmpty {
                print("No deployments fetched. Configure providers via the GUI Settings → Services pane.")
            } else {
                for deployment in filtered {
                    print(formatRow(deployment))
                }
            }
            if !errors.isEmpty {
                print("")
                print("Errors:")
                for (providerID, error) in errors {
                    print("  \(providerID): \(error.localizedDescription)")
                }
            }
        }

        if !errors.isEmpty && filtered.isEmpty {
            // Non-zero exit when nothing came back AND we have errors — useful
            // for CI checks like "fail my build if all providers are broken".
            throw ExitCode.failure
        }
    }

    private func formatRow(_ deployment: Deployment) -> String {
        let status = deployment.status.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)
        let provider = deployment.providerID.padding(toLength: 14, withPad: " ", startingAt: 0)
        let project = String(deployment.projectName.prefix(28)).padding(toLength: 28, withPad: " ", startingAt: 0)
        let branch = deployment.branch.map { "(\($0)) " } ?? ""
        return "\(status) \(provider) \(project) \(branch)\(deployment.relativeTime)"
    }
}
