import ArgumentParser
import Foundation

/// Output format flag shared across every command.
enum OutputFormat: String, ExpressibleByArgument {
    case plain
    case json
}

/// Reusable `--json` / `--plain` flag group.
struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Emit machine-readable JSON instead of a human-readable table.")
    var json: Bool = false

    @Flag(name: .long, help: "Force human-readable plain text (overrides --json).")
    var plain: Bool = false

    var format: OutputFormat {
        if plain { return .plain }
        if json { return .json }
        return .plain
    }
}

func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    if let text = String(data: data, encoding: .utf8) {
        print(text)
    }
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
}

/// Exits with code 1 — used by every command's catch handler so the shell
/// can detect failures (`$?`, CI guards, etc.).
func exitWithError(_ message: String) -> Never {
    printError(message)
    exit(1)
}
