import SwiftUI
import AppKit
import UniformTypeIdentifiers
import StackLightCore

/// Advanced / diagnostics pane. Mirrors RepoBar's DebugSettingsView — gives
/// power users (and bug-reporters) a one-click way to capture HTTP traces,
/// inspect cache state, and clear caches without dropping into the CLI.
struct AdvancedSettingsDetail: View {
    @EnvironmentObject var appState: AppState
    @SettingsValue(\.diagnosticsEnabled) private var diagnosticsEnabled: Bool
    @SettingsValue(\.fileLoggingEnabled) private var fileLoggingEnabled: Bool
    @SettingsValue(\.loggingVerbosity) private var verbosityRaw: String
    @State private var lastCleared: Date?
    @State private var cacheStats: StackLightCacheSummary?
    @State private var migrationNotice: MigrationNotice?

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
                        Text("Logs every HTTP request. Visible in the Logs pane here, and in Console.app under subsystem app.yellowplus.StackLight. Errors and warnings are recorded in the Logs pane even when this is off.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: diagnosticsEnabled) { value in
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
                .onChange(of: fileLoggingEnabled) { value in
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
                .onChange(of: verbosityRaw) { value in
                    Task { await DiagnosticsLogger.shared.setVerbosity(value) }
                }
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
                if let stats = cacheStats {
                    HStack {
                        Text("API responses cached")
                        Spacer()
                        Text("\(stats.apiResponseCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Tracked rate limits")
                        Spacer()
                        Text("\(stats.rateLimitCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Cache file")
                        Spacer()
                        Text(stats.databasePath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Button("Clear HTTP Cache") {
                    Task {
                        await RequestRunner.shared.clear()
                        _ = try? PersistentCache.clear()
                        await MainActor.run {
                            lastCleared = Date()
                            refreshCacheStats()
                        }
                    }
                }
                if let lastCleared {
                    Text("Last cleared: \(lastCleared.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Configuration") {
                Button("Export Settings…") {
                    exportSettings()
                }

                Button("Import Settings…") {
                    importSettings()
                }

                Text("Exports app preferences, provider project lists, and pinned/hidden state. API tokens stay in Keychain and must be re-entered on the target device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshCacheStats() }
        .alert(item: $migrationNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func refreshCacheStats() {
        cacheStats = try? PersistentCache.summary(limit: 0)
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

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "stacklight-settings.json"
        panel.title = "Export StackLight Settings"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try SettingsStore.shared.exportData()
            try data.write(to: url, options: .atomic)
            migrationNotice = MigrationNotice(
                title: "Settings Exported",
                message: "Secrets are not included. Re-enter API tokens on the target device."
            )
        } catch {
            migrationNotice = MigrationNotice(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Import StackLight Settings"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try SettingsStore.shared.importData(data)
            appState.restartPolling()
            migrationNotice = MigrationNotice(
                title: "Settings Imported",
                message: "Secrets are not included. Re-enter API tokens on this device."
            )
        } catch {
            migrationNotice = MigrationNotice(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }
}

private struct MigrationNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
