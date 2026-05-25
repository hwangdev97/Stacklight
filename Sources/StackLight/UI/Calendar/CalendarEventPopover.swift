import SwiftUI

struct CalendarEventPopover: View {
    @Environment(\.openURL) private var openURL
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(event.providerLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(event.providerColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(event.providerColor)
                Text(event.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                detailRow("When", event.startsAt.formatted(date: .abbreviated, time: .shortened))
                if let branch = event.branch, !branch.isEmpty {
                    detailRow("Branch", branch)
                }
                if let repository = event.repository, !repository.isEmpty {
                    detailRow("Repository", repository)
                }
            }

            if let url = event.url {
                Divider()
                Button {
                    openURL(url)
                } label: {
                    Label("Open in Browser", systemImage: "arrow.up.right")
                }
            }
        }
        .padding(14)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
