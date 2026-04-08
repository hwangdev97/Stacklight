import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Sidebar Item

private enum SettingsItem: Hashable {
    case provider(String) // provider id
    case general
}

// MARK: - Root Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: SettingsItem = .provider(ServiceRegistry.shared.providers.first?.id ?? "")

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Services") {
                    ForEach(ServiceRegistry.shared.providers, id: \.id) { provider in
                        Label(provider.displayName, systemImage: provider.iconSymbol)
                            .tag(SettingsItem.provider(provider.id))
                    }
                }
                Section {
                    Label("General", systemImage: "gear")
                        .tag(SettingsItem.general)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selection {
            case .provider(let id):
                if let provider = ServiceRegistry.shared.provider(withID: id) {
                    ProviderSettingsTab(provider: provider)
                        .id(id)
                }
            case .general:
                GeneralSettingsTab()
            }
        }
        .frame(width: 580, height: 380)
    }
}

// MARK: - Provider Settings

struct ProviderSettingsTab: View {
    let provider: DeploymentProvider
    @State private var fieldValues: [String: String] = [:]
    @State private var saved = false
    @State private var testing = false
    @State private var testResult: TestResult?
    @EnvironmentObject var appState: AppState

    private enum TestResult {
        case success(Int)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: provider.iconSymbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(provider.displayName)
                    .font(.title3.weight(.semibold))
                Spacer()
                if let docsURL = provider.docsURL {
                    Button {
                        NSWorkspace.shared.open(docsURL)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Get credentials")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(.bottom, 16)

            // Fields
            Grid(alignment: .trailing, verticalSpacing: 10) {
                ForEach(provider.settingsFields()) { field in
                    GridRow {
                        Text(field.label)
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)

                        VStack(alignment: .leading, spacing: 3) {
                            if field.isSecret {
                                SecureField("", text: binding(for: field), prompt: Text(field.placeholder))
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                TextField("", text: binding(for: field), prompt: Text(field.placeholder))
                                    .textFieldStyle(.roundedBorder)
                            }
                            if let hint = field.hint {
                                Text(hint)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Buttons
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
                        .transition(.opacity)
                }

                Spacer()

                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 4) {
                        if testing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Test")
                    }
                }
                .disabled(testing)

                if let testResult {
                    switch testResult {
                    case .success(let count):
                        Label("\(count) deployments", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    case .failure(let msg):
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(20)
        .onAppear { loadFields() }
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

    private func testConnection() {
        // Save first so the provider picks up current values
        saveFields()
        testing = true
        testResult = nil
        Task {
            do {
                let deployments = try await provider.fetchDeployments()
                testResult = .success(deployments.count)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            testing = false
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            testResult = nil
        }
    }

    private func saveFields() {
        for field in provider.settingsFields() {
            let value = (fieldValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if field.isSecret {
                if value.isEmpty {
                    KeychainManager.delete(key: field.key)
                } else {
                    try? KeychainManager.save(key: field.key, value: value)
                }
            } else {
                UserDefaults.standard.set(value, forKey: field.key)
            }
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @AppStorage("pollInterval") private var pollInterval: Double = 60
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("General")
                    .font(.title3.weight(.semibold))
            }
            .padding(.bottom, 16)

            Form {
                Section("Polling") {
                    HStack {
                        Text("Refresh every")
                        Slider(value: $pollInterval, in: 30...300, step: 30)
                            .frame(maxWidth: 180)
                        Text("\(Int(pollInterval))s")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
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
            }
            .formStyle(.grouped)

            Spacer()

            Text("ShapeBar — Deployment Monitor")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
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
