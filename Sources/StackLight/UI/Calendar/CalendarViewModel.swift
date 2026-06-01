import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case month = "Month"
        case week = "Week"

        var id: String { rawValue }
    }

    @Published var anchorDate: Date
    @Published var mode: Mode = .month
    @Published var selectedEvent: CalendarEvent?
    @Published var selectedAgendaEvent: CalendarEvent?

    let calendar: Calendar

    init(anchorDate: Date = Date(), calendar: Calendar = .current) {
        self.anchorDate = anchorDate
        self.calendar = calendar
    }

    func today() {
        anchorDate = Date()
    }

    func step(_ delta: Int) {
        let component: Calendar.Component = mode == .month ? .month : .weekOfYear
        anchorDate = calendar.date(byAdding: component, value: delta, to: anchorDate) ?? anchorDate
    }

    func showWeek(containing date: Date) {
        anchorDate = date
        mode = .week
    }

    func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    func isSameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.component(.year, from: lhs) == calendar.component(.year, from: rhs)
            && calendar.component(.month, from: lhs) == calendar.component(.month, from: rhs)
    }

    func monthGridDates() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: anchorDate),
              let gridStart = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)?.start
        else { return [] }
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    func weekDates() -> [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: anchorDate)?.start else {
            return []
        }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    func bucketByDay(_ events: [CalendarEvent]) -> [Date: [CalendarEvent]] {
        Dictionary(grouping: events) { startOfDay($0.startsAt) }
            .mapValues { $0.sorted { $0.startsAt < $1.startsAt } }
    }
}
