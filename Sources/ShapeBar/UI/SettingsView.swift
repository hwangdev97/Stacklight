import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            ForEach(ServiceRegistry.shared.providers, id: \.id) { provider in
                ProviderSettingsTab(provider: provider)
                    .tabItem {
                        Label(provider.displayName, systemImage: provider.iconSymbol)
                    }
            }

            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct ProviderSettingsTab: View {
    let provider: DeploymentProvider
    @State private var fieldValues: [String: String] = [:]
    @State private var saved = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            ForEach(provider.settingsFields()) { field in
                if field.isSecret {
                    SecureField(field.label, text: binding(for: field))
                        .textFieldStyle(.roundedBorder)
                        .help(field.placeholder)
                } else {
                    TextField(field.label, text: binding(for: field), prompt: Text(field.placeholder))
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Button("Save") {
                    saveFields()
                    saved = true
                    appState.restartPolling()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        saved = false
                    }
                }
                .keyboardShortcut(.defaultAction)

                if saved {
                    Text("Saved!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding()
        .onAppear {
            loadFields()
        }
    }

    private func binding(for field: SettingsField) -> Binding<String> {
        Binding(
            get: { fieldValues[field.key] ?? "" },
            set: { fieldValues[field.key] = $0 }
        )
    }

    private func loadFields() {
        for field in provider.settingsFields() {
            if field.isSecret {
                fieldValues[field.key] = KeychainManager.read(key: field.key) ?? ""
            } else {
                fieldValues[field.key] = UserDefaults.standard.string(forKey: field.key) ?? ""
            }
        }
    }

    private func saveFields() {
        for field in provider.settingsFields() {
            let value = fieldValues[field.key] ?? ""
            if field.isSecret {
                try? KeychainManager.save(key: field.key, value: value)
            } else {
                UserDefaults.standard.set(value, forKey: field.key)
            }
        }
    }
}

struct GeneralSettingsTab: View {
    @AppStorage("pollInterval") private var pollInterval: Double = 60
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Polling") {
                HStack {
                    Text("Refresh interval:")
                    Slider(value: $pollInterval, in: 30...300, step: 30) {
                        Text("Interval")
                    }
                    Text("\(Int(pollInterval))s")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section("Notifications") {
                Toggle("Notify on status changes", isOn: $notificationsEnabled)
                Text("Get alerts when deployments fail or complete.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("About") {
                Text("ShapeBar — Deployment Monitor")
                    .font(.headline)
                Text("A unified menubar app for monitoring deployments across Vercel, Cloudflare, Xcode Cloud, and TestFlight.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
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
            // Revert toggle
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
