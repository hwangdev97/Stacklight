import SwiftUI
import AppKit
import UniformTypeIdentifiers
import StackLightCore

/// Settings → Logs. Live console over `LogStore` — the reliable place to read
/// an error even when the inline SwiftUI rendering elsewhere truncated or
/// swallowed it. Errors and warnings are always recorded; enabling
/// Diagnostics (Advanced pane) adds the per-request HTTP traffic.
struct LogsSettingsDetail: View {
    @ObservedObject private var logStore = LogStore.shared
    @SettingsValue(\.diagnosticsEnabled) private var diagnosticsEnabled: Bool
    /// Minimum severity to display; `.debug` means "everything".
    @State private var minLevel: LogEntry.Level = .debug
    @State private var searchText = ""
    @State private var copied = false

    /// Newest first — new entries appear at the top, no scroll chasing.
    private var filtered: [LogEntry] {
        logStore.entries.reversed().filter { entry in
            entry.level >= minLevel
                && (searchText.isEmpty
                    || entry.message.localizedCaseInsensitiveContains(searchText)
                    || entry.category.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { entry in
                        LogEntryRow(entry: entry)
                            .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                    }
                }
                .listStyle(.plain)
            }
            Divider()
            footer
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.gray.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text("Logs")
                .font(.title3.weight(.semibold))
            Spacer()
            if logStore.errorCount > 0 {
                Text("\(logStore.errorCount) error\(logStore.errorCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Picker("", selection: $minLevel) {
                Text("All").tag(LogEntry.Level.debug)
                Text("Info").tag(LogEntry.Level.info)
                Text("Warnings").tag(LogEntry.Level.warning)
                Text("Errors").tag(LogEntry.Level.error)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Filter", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )

            Button(copied ? "Copied" : "Copy") { copyAll() }
                .disabled(filtered.isEmpty)
            Button("Export…") { exportLogs() }
                .disabled(filtered.isEmpty)
            Button("Clear") { logStore.clear() }
                .disabled(logStore.entries.isEmpty)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(logStore.entries.isEmpty ? "No log entries yet" : "No entries match the filter")
                .font(.callout)
                .foregroundStyle(.secondary)
            if logStore.entries.isEmpty, !diagnosticsEnabled {
                Text("Errors and warnings are always recorded here. Enable Diagnostics in Advanced to also capture every HTTP request.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(filtered.count) of \(logStore.entries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            if !diagnosticsEnabled {
                Text("Diagnostics off — recording errors and warnings only")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func copyAll() {
        // Chronological order (oldest first) reads naturally when pasted.
        let text = LogStore.exportText(filtered.reversed())
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    private func exportLogs() {
        let text = LogStore.exportText(filtered.reversed())

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "StackLight-logs-\(formatter.string(from: Date())).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Row

private struct LogEntryRow: View {
    let entry: LogEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 9))
                .foregroundStyle(color)
                .frame(width: 12)

            Text(Self.timeFormatter.string(from: entry.date))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(entry.category)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color(nsColor: .quaternaryLabelColor)))
                .lineLimit(1)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .help(entry.message)
    }

    private var symbol: String {
        switch entry.level {
        case .debug: return "circle.dashed"
        case .info: return "circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch entry.level {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Previews

#Preview("Settings — Logs") {
    LogsSettingsDetail()
        .frame(width: 480, height: 500)
        .onAppear {
            LogStore.shared.append(LogEntry(level: .info, category: "http", message: "HTTP GET api.vercel.com/v6/deployments status=200 dur=182ms bytes=5121"))
            LogStore.shared.append(LogEntry(level: .warning, category: "githubActions", message: "2 item(s) failed — owner/repo: HTTP 404: not found"))
            LogStore.shared.append(LogEntry(level: .error, category: "xcodeCloud", message: "Test failed: The request timed out."))
        }
}
