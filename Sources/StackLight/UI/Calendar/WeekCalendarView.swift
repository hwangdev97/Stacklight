import SwiftUI

struct WeekCalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]

    private let hourHeight: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.65)
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    hourLabels
                    ForEach(viewModel.weekDates(), id: \.self) { date in
                        dayColumn(date)
                    }
                }
                .frame(minHeight: hourHeight * 24)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 56)
            ForEach(viewModel.weekDates(), id: \.self) { date in
                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.calendar.component(.day, from: date))")
                        .font(.title3.weight(viewModel.calendar.isDateInToday(date) ? .bold : .semibold))
                        .foregroundStyle(viewModel.calendar.isDateInToday(date) ? Color.accentColor : Color.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 6)
            }
        }
    }

    private func dayColumn(_ date: Date) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: hourHeight)
                        .overlay(alignment: .top) {
                            Divider().opacity(0.55)
                        }
                }
            }

            ForEach(eventsForDay(date)) { event in
                weekEvent(event)
            }

            if viewModel.calendar.isDateInToday(date) {
                nowLine
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hourHeight * 24)
        .background(viewModel.calendar.isDateInToday(date) ? Color.accentColor.opacity(0.025) : Color.clear)
        .overlay(alignment: .trailing) {
            Divider().opacity(0.45)
        }
    }

    private func weekEvent(_ event: CalendarEvent) -> some View {
        let top = eventTop(event.startsAt)
        let height: CGFloat = 34

        return CalendarEventPill(event: event) {
            viewModel.selectedEvent = event
        }
        .padding(.horizontal, 4)
        .frame(height: height)
        .offset(y: top)
    }

    private var nowLine: some View {
        Rectangle()
            .fill(Color.red)
            .frame(height: 1)
            .offset(y: eventTop(Date()))
    }

    private func eventsForDay(_ date: Date) -> [CalendarEvent] {
        events
            .filter { viewModel.isSameDay($0.startsAt, date) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func eventTop(_ date: Date) -> CGFloat {
        let comps = viewModel.calendar.dateComponents([.hour, .minute], from: date)
        let hour = CGFloat(comps.hour ?? 0)
        let minute = CGFloat(comps.minute ?? 0)
        return (hour + minute / 60) * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}
