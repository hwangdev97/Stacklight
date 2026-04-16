import SwiftUI
import ServiceManagement

// MARK: - General Settings Detail (System Settings style)

struct GeneralSettingsDetail: View {
    @AppStorage("pollInterval") private var pollInterval: Double = 60
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "gear")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("General")
                    .font(.title2.weight(.semibold))

                Text("Manage polling, notifications, and startup behavior.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Polling section
            settingsCard {
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
            .padding(.horizontal, 20)

            // Notifications section
            settingsCard {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Notify on status changes", systemImage: "bell.badge")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Startup section
            settingsCard {
                VStack(alignment: .leading, spacing: 4) {
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // About section
            settingsCard {
                VStack(spacing: 0) {
                    row(label: "App", value: "StackLight")
                    Divider().padding(.leading, 16)
                    row(label: "Version", value: "1.0.0")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer(minLength: 20)
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
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
