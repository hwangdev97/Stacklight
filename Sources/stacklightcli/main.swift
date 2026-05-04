import ArgumentParser
import Foundation
import StackLightCore

/// Top-level entry point. Mirrors RepoBar's CLI surface — small set of
/// commands that exercise exactly the same Core paths the GUI uses, so any
/// "why is the menu showing X?" question can be reproduced and diagnosed
/// from the terminal.
@main
struct StackLightCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stacklight",
        abstract: "Inspect and exercise StackLight's providers and cache.",
        version: "0.1.0",
        subcommands: [
            DeploymentsCommand.self,
            TestCommand.self,
            ProvidersCommand.self,
            CacheCommand.self,
            RateLimitsCommand.self,
            SettingsCommand.self
        ]
    )
}
