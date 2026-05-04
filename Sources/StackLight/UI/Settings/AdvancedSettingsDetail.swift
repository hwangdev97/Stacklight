import SwiftUI
import AppKit
import StackLightCore

/// Advanced / diagnostics pane. Mirrors RepoBar's DebugSettingsView — gives
/// power users (and bug-reporters) a one-click way to capture HTTP traces,
/// inspect cache state, and clear caches without dropping into the CLI.
struct AdvancedSettingsDetail: View {
    @AppStorage("diagnosticsEnabled") private var diagnosticsEnabled: Bool = false
    @AppStorage("fileLoggingEnabled") private var fileLoggingEnabled: Bool = false
    @AppStorage("loggingVerbosity") private var verbosityRaw: String = LogVerbosity.info.rawValue
    @State private var lastCleared: Date?

    enum LogVerbosity: String, CaseIterable, Identifiable {
        case debug, info, warning
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .debug: return "Debug (everything)"
            case .info: return "Info (default)"
            case .warning: return "Warning (errors only)"
            }
        }
    }

    private var verbosity: LogVerbosity {
        get { LogVerbosity(rawValue: verbosityRaw) ?? .info }
    }

    var body: some View {
        Form {
            VStack(spacing: 8) {
                GlassDetailIcon(color: .gray, systemImage: "wrench.and.screwdriver")

                Text("Advanced")
                    .font(.title2.weight(.semibold))

                Text("Diagnostics, logs, and cache management for debugging.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .center)

            Section("Diagnostics") {
                Toggle(isOn: $diagnosticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Diagnostics")
                        Text("Logs every HTTP request to the unified log. Visible in Console.app under subsystem app.yellowplus.StackLight.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: diagnosticsEnabled) { _, value in
                    Task { await DiagnosticsLogger.shared.setEnabled(value) }
                }

                Toggle(isOn: $fileLoggingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Write Logs to File")
                        Text("Mirror diagnostics into ~/Library/Logs/StackLight/diagnostics.log (rotates at 1 MB, keeps 5 files).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!diagnosticsEnabled)
                .onChange(of: fileLoggingEnabled) { _, value in
                    Task { await DiagnosticsLogger.shared.setFileLogging(value) }
                }

                Picker("Verbosity", selection: Binding(
                    get: { LogVerbosity(rawValue: verbosityRaw) ?? .info },
                    set: { verbosityRaw = $0.rawValue }
                )) {
                    ForEach(LogVerbosity.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .disabled(!diagnosticsEnabled)
            }

            Section("Logs") {
                Button("Open Logs Folder in Finder") {
                    openLogsFolder()
                }
                .disabled(!fileLoggingEnabled)

                Button("Open Console.app (live diagnostics)") {
                    openConsole()
                }
            }

            Section("Cache") {
                Button("Clear HTTP Cache") {
                    Task {
                        await RequestRunner.shared.clear()
                        // P4.x: also clears persistent SQLite cache once that lands.
                        await MainActor.run { lastCleared = Date() }
                    }
                }
                if let lastCleared {
                    Text("Last cleared: \(lastCleared.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func openLogsFolder() {
        guard let dir = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/StackLight", isDirectory: true)
        else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    private func openConsole() {
        if let consoleURL = URL(string: "/System/Applications/Utilities/Console.app") {
            NSWorkspace.shared.open(consoleURL)
        }
    }
}
