import SwiftUI
import StackLightCore

struct CalendarWindow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel = CalendarViewModel()

    private var providersByID: [String: DeploymentProvider] {
        Dictionary(uniqueKeysWithValues: ServiceRegistry.shared.providers.map { ($0.id, $0) })
    }

    private var events: [CalendarEvent] {
        appState.deployments
            .map { CalendarEvent(deployment: $0, provider: providersByID[$0.providerID]) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    var body: some View {
        NavigationSplitView {
            AgendaSidebarView(
                viewModel: viewModel,
                events: events,
                errors: appState.errors,
                providers: ServiceRegistry.shared.configuredProviders,
                isRefreshing: appState.isRefreshing,
                lastRefresh: appState.lastRefresh,
                onRefresh: { appState.refresh() },
                onOpenSettings: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                ZStack {
                    if viewModel.mode == .month {
                        MonthCalendarView(viewModel: viewModel, events: events)
                    } else {
                        WeekCalendarView(viewModel: viewModel, events: events)
                    }

                    if events.isEmpty {
                        emptyOverlay
                    }
                }
            }
            .frame(minWidth: 640, minHeight: 520)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    viewModel.step(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Previous")

                Button("Today") {
                    viewModel.today()
                }

                Button {
                    viewModel.step(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Next")
            }

            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .frame(minWidth: 180)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Picker("View", selection: $viewModel.mode) {
                    ForEach(CalendarViewModel.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
        }
        .popover(item: $viewModel.selectedEvent, arrowEdge: .trailing) { event in
            CalendarEventPopover(event: event)
                .frame(width: 300)
        }
    }

    private var title: String {
        if viewModel.mode == .month {
            return viewModel.anchorDate.formatted(.dateTime.month(.wide).year())
        }
        let week = viewModel.weekDates()
        guard let first = week.first, let last = week.last else {
            return viewModel.anchorDate.formatted(.dateTime.month(.wide).year())
        }
        if viewModel.isSameMonth(first, last) {
            return "\(first.formatted(.dateTime.month(.wide).day())) - \(last.formatted(.dateTime.day().year()))"
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) - \(last.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    @ViewBuilder
    private var emptyOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: ServiceRegistry.shared.configuredProviders.isEmpty ? "calendar.badge.exclamationmark" : "calendar")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
            Text(ServiceRegistry.shared.configuredProviders.isEmpty ? "No services configured" : "No recent records")
                .font(.headline.weight(.semibold))
            Text(ServiceRegistry.shared.configuredProviders.isEmpty ? "Open Settings to add API tokens." : "Refresh to load the latest provider activity.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(28)
    }
}
