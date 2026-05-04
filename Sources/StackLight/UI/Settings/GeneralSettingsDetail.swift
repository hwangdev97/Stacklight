import SwiftUI
import ServiceManagement
import StackLightCore

// MARK: - General Settings Detail (System Settings style)

struct GeneralSettingsDetail: View {
    @SettingsValue(\.pollIntervalSeconds) private var pollInterval: Double
    @SettingsValue(\.notificationsEnabled) private var notificationsEnabled: Bool
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            VStack(spacing: 8) {
                GlassDetailIcon(color: .gray, systemImage: "gear")

                Text("General")
                    .font(.title2.weight(.semibold))

                Text("Manage polling, notifications, and startup behavior.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .center)
            
            Section {
                HStack {
                    Label("Refresh interval", systemImage: "arrow.clockwise")
                    Spacer()
                    Slider(value: $pollInterval, in: 30...300, step: 30)
                        .frame(width: 120)
                    Text("\(Int(pollInterval))s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
            

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Notify on status changes", systemImage: "bell.badge")
                }

                Toggle(isOn: $launchAtLogin) {
                    Label("Launch at login", systemImage: "play.circle")
                }
                .onChange(of: launchAtLogin) { newValue in
                    toggleLaunchAtLogin(enabled: newValue)
                }

                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section {
                row(label: "App", value: "StackLight")
                row(label: "Version", value: UpdateChecker.currentVersion)
                row(label: "Distribution", value: UpdateChecker.channel.displayName)
                Button {
                    Task {
                        let result: Result<UpdateCheckResult, Error>
                        do {
                            result = .success(try await UpdateChecker.checkForUpdates())
                        } catch {
                            result = .failure(error)
                        }
                        await MainActor.run {
                            UpdateChecker.presentUpdateCheckResult(result)
                        }
                    }
                } label: {
                    Label(updateButtonTitle, systemImage: "arrow.down.circle")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updateButtonTitle: String {
        switch UpdateChecker.channel {
        case .github:
            return "Check for Updates"
        case .macAppStore:
            return "Updates via Mac App Store"
        case .development:
            return "Check for Updates"
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Previews

#Preview("Settings — General") {
    GeneralSettingsDetail()
        .frame(width: 480, height: 500)
}
