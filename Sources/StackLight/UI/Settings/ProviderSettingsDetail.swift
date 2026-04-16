import SwiftUI

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
                providerDetailIcon(provider)

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

    @ViewBuilder
    private func providerDetailIcon(_ provider: DeploymentProvider) -> some View {
        if let asset = provider.iconAsset {
            Image(asset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .frame(width: 56, height: 56)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Image(systemName: provider.iconSymbol)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        ASCCredentialStore.invalidate()
    }
}

// MARK: - Previews

#Preview("Settings — Provider") {
    ProviderSettingsDetail(provider: ServiceRegistry.shared.providers.first!)
        .environmentObject(AppState())
        .frame(width: 480, height: 500)
}
