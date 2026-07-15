import AppKit
import StackLightCore

/// Shared plumbing for handing an AI prompt to the user's agent of choice.
/// Used by the provider Settings pane (configuration errors) and the menu
/// bar error hover card / context menu (deployment failures).
///
/// Two paths:
/// - copy the prompt to the general pasteboard, or
/// - additionally launch the agent CLI (`claude` / `codex`) in Terminal via
///   a temporary `.command` script (the prompt is always copied first, so
///   the user has it even if the CLI is missing).
@MainActor
enum AgentHandoff {
    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Copies `prompt` and opens Terminal running the CLI with it. Returns a
    /// short status line for transient UI feedback ("Copied prompt and
    /// opened Claude").
    static func launchInTerminal(_ cli: AIErrorHandoffCLI, prompt: String) -> String {
        copyToPasteboard(prompt)
        do {
            let scriptURL = try writeCommandScript(for: cli, prompt: prompt)
            if NSWorkspace.shared.open(scriptURL) {
                return "Copied prompt and opened \(cli.displayName)"
            }
            return "Copied prompt; could not open \(cli.displayName)"
        } catch {
            return "Copied prompt; \(error.localizedDescription)"
        }
    }

    /// Writes a self-deleting-ish `.command` script that runs the CLI with
    /// the prompt as its argument. Opening a `.command` file is the only
    /// sandbox-friendly way to hand a long argv to Terminal.
    static func writeCommandScript(for cli: AIErrorHandoffCLI, prompt: String) throws -> URL {
        let filename = "StackLight-\(cli.executableName)-\(UUID().uuidString).command"
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let quotedPrompt = AIErrorHandoff.shellQuoted(prompt)
        let quotedExecutable = AIErrorHandoff.shellQuoted(cli.executableName)
        let script = """
        #!/bin/zsh
        export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

        if ! command -v \(quotedExecutable) >/dev/null 2>&1; then
          echo "\(cli.displayName) CLI not found."
          echo "The StackLight error prompt has been copied to the clipboard."
          echo "Install \(cli.displayName) CLI or paste the prompt into your AI assistant."
          echo
          read -r "?Press Return to close."
          exit 127
        fi

        \(cli.executableName) \(quotedPrompt)
        status=$?
        echo
        echo "\(cli.displayName) exited with status $status."
        read -r "?Press Return to close."
        exit $status
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
    }
}
