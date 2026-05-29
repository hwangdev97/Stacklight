import SwiftUI
import UniformTypeIdentifiers
import StackLightCore

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @SettingsValue(\.pollIntervalSeconds) private var pollInterval: Double
    @SettingsValue(\.notificationsEnabled) private var notificationsEnabled: Bool
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument = SettingsExportDocument(data: Data())
    @State private var migrationNotice: MigrationNotice?

    var body: some View {
        ZStack {
            DesignTokens.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    SettingsCard(title: "Refresh Interval",
                                 footer: "How often StackLight fetches new deployment data.") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            HStack {
                                Label("Interval", systemImage: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(pollInterval))s")
                                    .font(DesignTokens.Typography.numeric(size: 18))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .liquidGlassChip()
                            }

                            Slider(value: $pollInterval, in: 30...300, step: 30) {
                                Text("Refresh interval")
                            } minimumValueLabel: {
                                Text("30s")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            } maximumValueLabel: {
                                Text("5m")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .tint(DesignTokens.Palette.review)
                            .onChange(of: pollInterval) { _, _ in
                                appState.restartPolling()
                            }
                        }
                    }

                    SettingsCard(title: "Notifications",
                                 footer: "Notify when a deployment succeeds or fails.") {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("Status Change Notifications", systemImage: "bell.badge")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .tint(DesignTokens.Palette.success)
                    }

                    SettingsCard(title: "Configuration",
                                 footer: "Exports app preferences, provider project lists, and pinned/hidden state. API tokens stay in Keychain and must be re-entered on the target device.") {
                        VStack(spacing: 2) {
                            Button {
                                exportSettings()
                            } label: {
                                actionRow(icon: "square.and.arrow.up", title: "Export Settings")
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(DesignTokens.Palette.hairline)

                            Button {
                                showImporter = true
                            } label: {
                                actionRow(icon: "square.and.arrow.down", title: "Import Settings")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .tint(.white)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "stacklight-settings"
        ) { result in
            switch result {
            case .success:
                migrationNotice = MigrationNotice(
                    title: "Settings Exported",
                    message: "Secrets are not included. Re-enter API tokens on the target device."
                )
            case .failure(let error):
                migrationNotice = MigrationNotice(
                    title: "Export Failed",
                    message: error.localizedDescription
                )
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            importSettings(result)
        }
        .alert(item: $migrationNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func actionRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func exportSettings() {
        do {
            exportDocument = SettingsExportDocument(data: try SettingsStore.shared.exportData())
            showExporter = true
        } catch {
            migrationNotice = MigrationNotice(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importSettings(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
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

private struct SettingsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct MigrationNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
            .environmentObject(AppState())
    }
    .preferredColorScheme(.dark)
}
