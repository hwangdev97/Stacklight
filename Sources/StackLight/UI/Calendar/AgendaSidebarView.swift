import SwiftUI
import StackLightCore

struct AgendaSidebarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]
    let errors: [String: String]
    let providers: [DeploymentProvider]
    let isRefreshing: Bool
    let lastRefresh: Date?
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section {
                miniCalendar
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section {
                agendaRows
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section {
                footer
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
            Text("StackLight")
                .font(.headline.weight(.semibold))
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    private var miniCalendar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.anchorDate.formatted(.dateTime.month(.wide).year()))
                    .font(.callout.weight(.semibold))
                Spacer()
                Button {
                    viewModel.anchorDate = viewModel.calendar.date(byAdding: .month, value: -1, to: viewModel.anchorDate) ?? viewModel.anchorDate
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Button {
                    viewModel.anchorDate = viewModel.calendar.date(byAdding: .month, value: 1, to: viewModel.anchorDate) ?? viewModel.anchorDate
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(shortWeekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(viewModel.monthGridDates(), id: \.self) { date in
                    miniDay(date)
                }
            }
        }
    }

    private func miniDay(_ date: Date) -> some View {
        let hasEvents = events.contains { viewModel.isSameDay($0.startsAt, date) }
        let isToday = viewModel.calendar.isDateInToday(date)
        let isSelected = viewModel.isSameDay(date, viewModel.anchorDate)
        let inMonth = viewModel.isSameMonth(date, viewModel.anchorDate)

        return Button {
            viewModel.anchorDate = date
        } label: {
            VStack(spacing: 1) {
                Text("\(viewModel.calendar.component(.day, from: date))")
                    .font(.caption)
                    .foregroundStyle(inMonth ? .primary : .tertiary)
                Circle()
                    .fill(hasEvents ? Color.accentColor : Color.clear)
                    .frame(width: 3, height: 3)
            }
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(isToday ? Color.accentColor.opacity(0.18) : (isSelected ? Color.secondary.opacity(0.10) : Color.clear))
            }
        }
        .buttonStyle(.plain)
    }

    private var agendaRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !errors.isEmpty {
                errorBlock
            }

            let agendaEvents = upcomingEvents
            if agendaEvents.isEmpty {
                Text(errors.isEmpty ? "Nothing scheduled in this range." : "No data - check provider credentials.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                ForEach(groupedAgendaDays, id: \.day) { group in
                    agendaGroup(group)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Provider issues", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
            ForEach(errors.sorted(by: { $0.key < $1.key }), id: \.key) { key, message in
                Text("\(key): \(message)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var upcomingEvents: [CalendarEvent] {
        let today = viewModel.startOfDay(Date())
        let upcoming = events.filter { $0.startsAt >= today }.prefix(30)
        if !upcoming.isEmpty { return Array(upcoming) }
        return Array(events.sorted { $0.startsAt > $1.startsAt }.prefix(8))
    }

    private var groupedAgendaDays: [(day: Date, events: [CalendarEvent])] {
        viewModel.bucketByDay(upcomingEvents)
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    private func agendaGroup(_ group: (day: Date, events: [CalendarEvent])) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dayLabel(group.day))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(group.day.formatted(.dateTime.month(.defaultDigits).day()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(group.events) { event in
                Button {
                    viewModel.selectedEvent = event
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(event.providerColor)
                            .frame(width: 7, height: 7)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.startsAt.formatted(.dateTime.hour().minute())) · \(event.providerLabel)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(event.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            if let subtitle = event.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRefreshing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing...")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let lastRefresh {
                Text("Updated \(SharedFormatters.relativeAbbreviated.localizedString(for: lastRefresh, relativeTo: Date()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if providers.isEmpty {
                Button("Open Settings", action: onOpenSettings)
                    .controlSize(.small)
            }
        }
    }

    private var shortWeekdays: [String] {
        viewModel.calendar.shortStandaloneWeekdaySymbols
    }

    private func dayLabel(_ date: Date) -> String {
        if viewModel.calendar.isDateInToday(date) { return "Today" }
        if viewModel.calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }
}
