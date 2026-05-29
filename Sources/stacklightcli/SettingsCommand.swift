import ArgumentParser
import Foundation
import StackLightCore

struct SettingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "settings",
        abstract: "Inspect, migrate, or mutate StackLight settings from the terminal.",
        subcommands: [Show.self, Export.self, Import.self, Pin.self, Hide.self, Reset.self],
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
            let settings = SettingsStore.shared.settings
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

    struct Export: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export non-secret settings to a JSON file."
        )

        @Option(name: [.short, .long], help: "Destination JSON file. Defaults to stdout.")
        var output: String?

        func run() async throws {
            let data = try SettingsStore.shared.exportData()

            guard let output else {
                if let text = String(data: data, encoding: .utf8) {
                    print(text)
                }
                return
            }

            let url = fileURL(from: output)
            if let parent = url.deletingLastPathComponent().path.nilIfEmpty {
                try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: .atomic)
            print("Exported settings to \(url.path)")
            print("Secrets are not included. Re-enter API tokens on the new device.")
        }
    }

    struct Import: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import non-secret settings from a JSON file."
        )

        @Argument(help: "Path to a JSON file created by 'stacklight settings export'.")
        var path: String

        func run() async throws {
            let url = fileURL(from: path)
            let data = try Data(contentsOf: url)
            try SettingsStore.shared.importData(data)
            print("Imported settings from \(url.path)")
            print("Secrets are not included. Re-enter API tokens on this device.")
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

private func fileURL(from path: String) -> URL {
    URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
