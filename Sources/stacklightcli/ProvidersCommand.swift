import ArgumentParser
import Foundation
import StackLightCore

struct ProvidersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "providers",
        abstract: "Inspect provider registration and configuration.",
        subcommands: [List.self, Status.self],
        defaultSubcommand: Status.self
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List every provider built into StackLight."
        )

        @OptionGroup
        var output: OutputOptions

        func run() async throws {
            let records = CLIContext.providerRecords()
            switch output.format {
            case .json:
                try printJSON(records)
            case .plain:
                for record in records {
                    let mark = record.configured ? "●" : "○"
                    print("  \(mark) \(record.id.padding(toLength: 16, withPad: " ", startingAt: 0)) \(record.displayName)")
                }
            }
        }
    }

    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show which providers have valid credentials configured."
        )

        @OptionGroup
        var output: OutputOptions

        func run() async throws {
            let records = CLIContext.providerRecords()
            let configured = records.filter(\.configured)
            switch output.format {
            case .json:
                struct Payload: Encodable {
                    let total: Int
                    let configured: Int
                    let providers: [CLIContext.ProviderRecord]
                }
                try printJSON(Payload(
                    total: records.count,
                    configured: configured.count,
                    providers: records
                ))
            case .plain:
                print("\(configured.count)/\(records.count) providers configured")
                for record in records where record.configured {
                    print("  ✓ \(record.displayName)")
                }
                let missing = records.filter { !$0.configured }
                if !missing.isEmpty {
                    print("")
                    print("Not configured:")
                    for record in missing {
                        print("  · \(record.displayName)")
                    }
                }
            }
        }
    }
}
