import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Sidebar Item

private enum SettingsItem: Hashable {
    case provider(String)
    case general
    case feedback
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
                        sidebarRow(provider: provider)
                            .tag(SettingsItem.provider(provider.id))
                    }
                }
                Section {
                    Label("General", systemImage: "gear")
                        .tag(SettingsItem.general)
                    Label("Send Feedback", systemImage: "bubble.left.and.bubble.right")
                        .tag(SettingsItem.feedback)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            ScrollView {
                Group {
                    switch selection {
                    case .provider(let id):
                        if let provider = ServiceRegistry.shared.provider(withID: id) {
                            ProviderSettingsDetail(provider: provider)
                                .id(id)
                        }
                    case .general:
                        GeneralSettingsDetail()
                    case .feedback:
                        FeedbackView(onOpenGitHubSettings: {
                            selection = .provider("githubPRs")
                        })
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(width: 660, height: 500)
    }

    @ViewBuilder
    private func sidebarRow(provider: DeploymentProvider) -> some View {
        HStack {
            Label(provider.displayName, systemImage: provider.iconSymbol)
            Spacer()
            if provider.isConfigured {
                if appState.errors[provider.id] != nil {
                    Circle().fill(.red).frame(width: 8, height: 8)
                } else {
                    Circle().fill(.green).frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - Provider Detail (System Settings style)

struct ProviderSettingsDetail: View {
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
        VStack(spacing: 0) {
            // Header — like System Settings
            VStack(spacing: 8) {
                Image(systemName: provider.iconSymbol)
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(provider.displayName)
                    .font(.title2.weight(.semibold))

                if let docsURL = provider.docsURL {
                    Link(destination: docsURL) {
                        HStack(spacing: 2) {
                            Text("How to get credentials")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Error banner
            if let error = appState.errors[provider.id] {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(10)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            // Credential fields — grouped card style
            VStack(spacing: 0) {
                ForEach(Array(provider.settingsFields().enumerated()), id: \.element.id) { index, field in
                    if field.isMultiValue {
                        // Multi-value: rendered separately below
                    } else {
                        if index > 0 && !provider.settingsFields()[index - 1].isMultiValue {
                            Divider().padding(.leading, 16)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(field.label)
                                    .frame(width: 100, alignment: .leading)
                                    .foregroundStyle(.primary)
                                if field.isSecret {
                                    SecureField("", text: binding(for: field), prompt: Text(field.placeholder))
                                        .textFieldStyle(.plain)
                                } else {
                                    TextField("", text: binding(for: field), prompt: Text(field.placeholder))
                                        .textFieldStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                            if let hint = field.hint {
                                Text(hint)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
            .padding(.horizontal, 20)

            // Multi-value fields — tag list with add/remove
            ForEach(provider.settingsFields().filter { $0.isMultiValue }, id: \.id) { field in
                MultiValueFieldView(field: field, rawValue: binding(for: field))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            // Actions
            HStack(spacing: 12) {
                Button("Save") {
                    saveFields()
                    saved = true
                    appState.restartPolling()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                .keyboardShortcut(.defaultAction)

                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.opacity.combined(with: .scale))
                }

                Spacer()

                if let testResult {
                    Group {
                        switch testResult {
                        case .success(let count):
                            Label("\(count) deployments", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let msg):
                            Label(String(msg.prefix(40)), systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .help(msg)
                        }
                    }
                    .font(.caption)
                    .transition(.opacity)
                }

                Button {
                    testConnection()
                } label: {
                    if testing {
                        ProgressView().controlSize(.small).frame(width: 40)
                    } else {
                        Text("Test").frame(width: 40)
                    }
                }
                .disabled(testing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .animation(.easeInOut(duration: 0.2), value: saved)

            Spacer(minLength: 20)
        }
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

// MARK: - Multi-Value Field (add / remove tags)

struct MultiValueFieldView: View {
    let field: SettingsField
    @Binding var rawValue: String
    @State private var newItem: String = ""

    private var items: [String] {
        rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(.subheadline.weight(.medium))

            if let hint = field.hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Existing items
            if !items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        HStack {
                            Text(item)
                                .font(.body.monospaced())
                            Spacer()
                            Button {
                                removeItem(item)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )
            }

            // Add new item
            HStack(spacing: 8) {
                TextField("", text: $newItem, prompt: Text(field.placeholder))
                    .textFieldStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                    .onSubmit { addItem() }

                Button {
                    addItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !items.contains(trimmed) else { newItem = ""; return }

        var current = items
        current.append(trimmed)
        rawValue = current.joined(separator: ", ")
        newItem = ""
    }

    private func removeItem(_ item: String) {
        var current = items
        current.removeAll { $0 == item }
        rawValue = current.joined(separator: ", ")
    }
}
