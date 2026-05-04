import ArgumentParser
import Foundation
import StackLightCore

struct SettingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "settings",
        abstract: "Inspect or mutate pinned/hidden state from the terminal.",
        subcommands: [Show.self, Pin.self, Hide.self, Reset.self],
        defaultSubcommand: Show.self
    )

    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Print the current UserSettings envelope."
        )

        @OptionGroup
        var output: OutputOptions

        func run() async throws {
            let settings = SettingsStore.shared.load()
            switch output.format {
            case .json:
                try printJSON(settings)
            case .plain:
                print("Pinned (\(settings.pinnedItems.count)):")
                for item in settings.pinnedItems.sorted() { print("  · \(item)") }
                print("Hidden (\(settings.hiddenItems.count)):")
                for item in settings.hiddenItems.sorted() { print("  · \(item)") }
                if !settings.hiddenProviders.isEmpty {
                    print("Hidden providers (\(settings.hiddenProviders.count)):")
                    for item in settings.hiddenProviders.sorted() { print("  · \(item)") }
                }
            }
        }
    }

    struct Pin: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "pin",
            abstract: "Pin a deployment by key (provider:item)."
        )

        @Argument(help: "Deployment key in the form 'providerID:itemID'.")
        var key: String

        func run() async throws {
            guard let parsed = DeploymentKey(rawValue: key) else {
                exitWithError("invalid key '\(key)'. Expected 'providerID:itemID'.")
            }
            SettingsStore.shared.mutate { $0.setVisibility(.pinned, for: parsed) }
            print("Pinned \(parsed.rawValue)")
        }
    }

    struct Hide: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide a deployment by key (provider:item)."
        )

        @Argument(help: "Deployment key in the form 'providerID:itemID'.")
        var key: String

        func run() async throws {
            guard let parsed = DeploymentKey(rawValue: key) else {
                exitWithError("invalid key '\(key)'. Expected 'providerID:itemID'.")
            }
            SettingsStore.shared.mutate { $0.setVisibility(.hidden, for: parsed) }
            print("Hidden \(parsed.rawValue)")
        }
    }

    struct Reset: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reset",
            abstract: "Restore a deployment to default visibility."
        )

        @Argument(help: "Deployment key in the form 'providerID:itemID'.")
        var key: String

        func run() async throws {
            guard let parsed = DeploymentKey(rawValue: key) else {
                exitWithError("invalid key '\(key)'. Expected 'providerID:itemID'.")
            }
            SettingsStore.shared.mutate { $0.setVisibility(.visible, for: parsed) }
            print("Reset \(parsed.rawValue)")
        }
    }
}
