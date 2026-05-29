import SwiftUI

struct MonthCalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(viewModel.calendar.shortStandaloneWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            Divider().opacity(0.65)
            GeometryReader { proxy in
                let cellHeight = max(86, proxy.size.height / 6)
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(viewModel.monthGridDates(), id: \.self) { date in
                        dayCell(date)
                            .frame(height: cellHeight)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let dayEvents = eventsForDay(date)
        let visible = Array(dayEvents.prefix(3))
        let isToday = viewModel.calendar.isDateInToday(date)
        let inMonth = viewModel.isSameMonth(date, viewModel.anchorDate)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(viewModel.calendar.component(.day, from: date))")
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .foregroundStyle(inMonth ? .primary : .tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(isToday ? Color.accentColor.opacity(0.18) : Color.clear)
                    }
                Spacer()
            }

            ForEach(visible) { event in
                CalendarEventPill(event: event, compact: true) {
                    viewModel.selectedEvent = event
                }
            }

            if dayEvents.count > visible.count {
                Button("+\(dayEvents.count - visible.count) more") {
                    viewModel.showWeek(containing: date)
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(inMonth ? Color.clear : Color.secondary.opacity(0.025))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.65)
        }
        .overlay(alignment: .trailing) {
            Divider().opacity(0.45)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.showWeek(containing: date)
        }
    }

    private func eventsForDay(_ date: Date) -> [CalendarEvent] {
        events
            .filter { viewModel.isSameDay($0.startsAt, date) }
            .sorted { $0.startsAt < $1.startsAt }
    }
}

struct CalendarEventPill: View {
    let event: CalendarEvent
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(event.providerColor)
                    .frame(width: 6, height: 6)
                if compact {
                    Text(event.startsAt.formatted(.dateTime.hour().minute()))
                        .foregroundStyle(.secondary)
                }
                Text(event.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(statusBackground, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(event.subtitle ?? event.providerLabel)
    }

    private var statusBackground: Color {
        switch event.status {
        case .failed:
            return Color.red.opacity(0.10)
        case .building, .queued:
            return Color.orange.opacity(0.10)
        case .reviewing:
            return Color.blue.opacity(0.10)
        case .success:
            return event.providerColor.opacity(0.10)
        case .cancelled, .unknown:
            return Color.secondary.opacity(0.08)
        }
    }
}
