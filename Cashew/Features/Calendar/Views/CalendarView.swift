import SwiftUI

struct CalendarView: View {

    @Environment(AppContainer.self) private var container
    @Environment(OnboardingCoordinator.self) private var onboardingCoordinator
    @State private var selectedDate = Date()
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showTrips = true
    @State private var showEvents = true
    @State private var showTasks = true
    @State private var selectedTripStatuses: Set<TripStatus> = []
    @State private var selectedEventCategories: Set<EventCategory> = []
    @State private var showUpcoming = true
    @State private var showPast = false
    @State private var isCalendarCollapsed = false
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var showMonthPicker = false
    @State private var showFilterSheet = false

    private var tripService: TripServiceProtocol {
        container.tripService
    }

    private var eventService: EventServiceProtocol {
        container.eventService
    }

    private var dayPlannerService: DayPlannerServiceProtocol {
        container.dayPlannerService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                calendarHeader

                // Calendar card
                VStack(spacing: 0) {
                    if !isCalendarCollapsed {
                        TripHighlightCalendar(
                            selectedDate: $selectedDate,
                            displayedMonth: $displayedMonth,
                            trips: tripService.trips,
                            events: eventService.events,
                            tasks: dayPlannerService.allTasks
                        )
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    dragHandle
                }
                .background(AppTheme.surfaceContainerLowest)

                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error {
                    Spacer()
                    errorView(error)
                    Spacer()
                } else {
                    contentList
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TripDestination.self) { destination in
                TripDetailView(tripId: destination.id)
            }
            .navigationDestination(for: EventDestination.self) { destination in
                EventDetailView(eventId: destination.id)
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedDate) { _, newDate in
            let calendar = Calendar.current
            if !calendar.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = calendar.startOfMonth(for: newDate)
            }
            Task {
                do { try await dayPlannerService.generateTasksFromRoutines(for: newDate) }
                catch { print("[CalendarView] Failed to generate tasks for \(newDate): \(error)") }
            }
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerView(selectedMonth: $displayedMonth) { newDate in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    let calendar = Calendar.current
                    if calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) {
                        selectedDate = calendar.startOfDay(for: Date())
                    } else {
                        selectedDate = calendar.startOfMonth(for: newDate)
                    }
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            CalendarFilterSheet(
                showTrips: $showTrips,
                showEvents: $showEvents,
                showTasks: $showTasks,
                selectedTripStatuses: $selectedTripStatuses,
                selectedEventCategories: $selectedEventCategories,
                onReset: resetFilters
            )
        }
    }

    // MARK: - Header

    private var calendarHeader: some View {
        VStack(spacing: 0) {
            // Row 1: small "Calendar" label + Today + Filter
            HStack(alignment: .center, spacing: 10) {
                Text("Calendar")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if !Calendar.current.isDateInToday(selectedDate) ||
                   !Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            let cal = Calendar.current
                            selectedDate = cal.startOfDay(for: Date())
                            displayedMonth = cal.startOfMonth(for: Date())
                        }
                    } label: {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                filterButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            // Row 2: ← | Month Year ▾ | →
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        shiftDisplayedMonth(by: -1)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurface)
                        .frame(width: 44, height: 40)
                }

                Button {
                    showMonthPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.onSurface)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        shiftDisplayedMonth(by: 1)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurface)
                        .frame(width: 44, height: 40)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .background(AppTheme.surfaceContainerLowest)
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppTheme.surfaceContainerHigh)
                .frame(width: 40, height: 4)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -30 && !isCalendarCollapsed {
                        collapseCalendar()
                    } else if value.translation.height > 30 && isCalendarCollapsed {
                        expandCalendar()
                    }
                }
        )
    }

    private func collapseCalendar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isCalendarCollapsed = true
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func expandCalendar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isCalendarCollapsed = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func shiftDisplayedMonth(by value: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: newMonth)
            if calendar.isDate(newMonth, equalTo: Date(), toGranularity: .month) {
                selectedDate = calendar.startOfDay(for: Date())
            } else {
                selectedDate = calendar.startOfMonth(for: newMonth)
            }
        }
    }

    // MARK: - Content List

    private var contentList: some View {
        let selected = itemsForSelectedDate
        let upcoming = upcomingItems
        let past = pastItems
        let hasUpcoming = !upcoming.trips.isEmpty || !upcoming.events.isEmpty
        let hasPast = !past.trips.isEmpty || !past.events.isEmpty

        return ScrollView {
            VStack(spacing: 0) {
                selectedDateSection(selected)

                if hasUpcoming {
                    upcomingSection(upcoming)
                        .padding(.top, 16)
                }
                if hasPast {
                    pastSection(past)
                        .padding(.top, 16)
                }

                if !hasUpcoming && !hasPast {
                    Color.clear.frame(height: 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < -50 && !isCalendarCollapsed {
                        collapseCalendar()
                    } else if value.translation.height > 50 && isCalendarCollapsed {
                        expandCalendar()
                    }
                }
        )
        .background(AppTheme.background)
    }

    // MARK: - Sections

    private func selectedDateSection(_ items: (trips: [Trip], events: [Event], tasks: [DailyTask])) -> some View {
        let calendar = Calendar.current
        let isEmpty = items.trips.isEmpty && items.events.isEmpty && items.tasks.isEmpty
        let isToday = calendar.isDateInToday(selectedDate)
        let timedEvents = items.events.filter { !$0.isAllDay }
        let hasTimed = !timedEvents.isEmpty || items.tasks.contains { $0.startTime != nil }

        return VStack(alignment: .leading, spacing: 12) {
            // Date header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .textCase(.uppercase)

                    Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                if isToday {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)

            // Insights summary
            insightsView(items: items)

            if isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    Text("Nothing scheduled")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 28)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            } else {
                // Day timeline strip
                if hasTimed {
                    MiniTimelineStripView(
                        events: timedEvents,
                        tasks: items.tasks,
                        selectedDate: selectedDate
                    )
                }

                tripLinks(items.trips)
                eventLinks(items.events)
                if !items.tasks.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(items.tasks) { task in
                            CalendarTaskRow(task: task, service: dayPlannerService)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Insights

    private func insightsView(items: (trips: [Trip], events: [Event], tasks: [DailyTask])) -> some View {
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate)
        let ws = interval?.start ?? selectedDate
        let we = interval?.end ?? selectedDate.addingTimeInterval(7 * 24 * 60 * 60)

        let weekTotal =
            (showTrips ? tripService.trips.filter { $0.startDate < we && $0.endDate >= ws }.count : 0)
            + (showEvents ? eventService.events.filter { $0.date >= ws && $0.date < we }.count : 0)
            + (showTasks ? dayPlannerService.allTasks.filter { $0.date >= ws && $0.date < we }.count : 0)

        return HStack(spacing: 5) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.quaternary)

            Text(insightsSummaryText(
                trips: items.trips.count,
                events: items.events.count,
                tasks: items.tasks.count,
                weekTotal: weekTotal
            ))
            .font(.caption)
            .foregroundStyle(AppTheme.onSurfaceVariant)

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func insightsSummaryText(trips: Int, events: Int, tasks: Int, weekTotal: Int) -> String {
        let total = trips + events + tasks
        let dayPart: String
        switch (total, trips > 0, events > 0, tasks > 0) {
        case (0, _, _, _):
            dayPart = "Nothing today"
        case (_, true, false, false):
            dayPart = "\(trips) trip\(trips == 1 ? "" : "s") today"
        case (_, false, true, false):
            dayPart = "\(events) event\(events == 1 ? "" : "s") today"
        case (_, false, false, true):
            dayPart = "\(tasks) task\(tasks == 1 ? "" : "s") today"
        default:
            dayPart = "\(total) items today"
        }
        let weekPart = "\(weekTotal) this week"
        return "\(dayPart) · \(weekPart)"
    }

    private func upcomingSection(_ items: (trips: [Trip], events: [Event])) -> some View {
        let count = items.trips.count + items.events.count

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showUpcoming.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    Text("Upcoming")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .rotationEffect(.degrees(showUpcoming ? 90 : 0))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }
            .buttonStyle(.plain)

            if showUpcoming {
                VStack(spacing: 8) {
                    tripLinks(items.trips)
                    eventLinks(items.events)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func pastSection(_ items: (trips: [Trip], events: [Event])) -> some View {
        let count = items.trips.count + items.events.count

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showPast.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surfaceContainerHigh)
                            .frame(width: 28, height: 28)
                        Image(systemName: "clock.arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }

                    Text("Past")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.surfaceContainerHigh)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .rotationEffect(.degrees(showPast ? 90 : 0))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }
            .buttonStyle(.plain)

            if showPast {
                VStack(spacing: 8) {
                    tripLinks(items.trips)
                    eventLinks(items.events)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Reusable UI Components

    @ViewBuilder
    private func tripLinks(_ trips: [Trip]) -> some View {
        if !trips.isEmpty {
            VStack(spacing: 8) {
                ForEach(trips) { trip in
                    NavigationLink(value: TripDestination(id: trip.id)) {
                        TripCard(trip: trip, style: .compact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func eventLinks(_ events: [Event]) -> some View {
        if !events.isEmpty {
            VStack(spacing: 8) {
                ForEach(events) { event in
                    NavigationLink(value: EventDestination(id: event.id)) {
                        EventCard(event: event, style: .compact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button {
                Task { await loadData() }
            } label: {
                Text("Retry")
                    .secondaryActionButton(fullWidth: false)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Filter

    private var hasActiveFilters: Bool {
        !showTrips || !showEvents || !showTasks || !selectedTripStatuses.isEmpty || !selectedEventCategories.isEmpty
    }

    private var activeFilterCount: Int {
        [!showTrips, !showEvents, !showTasks].filter { $0 }.count
            + selectedTripStatuses.count
            + selectedEventCategories.count
    }

    private func resetFilters() {
        showTrips = true
        showEvents = true
        showTasks = true
        selectedTripStatuses.removeAll()
        selectedEventCategories.removeAll()
    }

    private var filterButton: some View {
        Button { showFilterSheet = true } label: {
            HStack(spacing: 6) {
                Image(systemName: hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text("Filters")
                    .font(AppTheme.TextStyle.captionBold)
                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(AppTheme.TextStyle.micro)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.warning)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(hasActiveFilters ? AppTheme.warning : AppTheme.onSurfaceVariant)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(hasActiveFilters ? AppTheme.warning.opacity(0.12) : AppTheme.surfaceContainerLow)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(hasActiveFilters ? AppTheme.warning.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                onboardingCoordinator.registerFrame(
                    id: "anchor_calendar_filter",
                    frame: frame
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private var itemsForSelectedDate: (trips: [Trip], events: [Event], tasks: [DailyTask]) {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)

        let trips = showTrips ? tripService.trips.filter { trip in
            let inRange = isTripOnDate(trip, date: selectedDay, calendar: calendar)
            return inRange && matchesTripFilter(trip)
        } : []

        let events = showEvents ? eventService.events.filter { event in
            isEventOnDate(event, date: selectedDay, calendar: calendar) && matchesEventFilter(event)
        } : []

        let tasks = showTasks ? dayPlannerService.allTasks
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { lhs, rhs in
                switch (lhs.startTime, rhs.startTime) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.title < rhs.title
                }
            } : []

        return (trips, events, tasks)
    }

    /// Active and upcoming trips/events, excluding items already shown for the selected date.
    private var upcomingItems: (trips: [Trip], events: [Event]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: selectedDate)

        let trips = showTrips ? tripService.trips.filter { trip in
            let status = trip.computedStatus
            guard status == .active || status == .upcoming || status == .planning else { return false }
            guard !isTripOnDate(trip, date: selectedDay, calendar: calendar) else { return false }
            return matchesTripFilter(trip)
        }
        .sorted { $0.startDate < $1.startDate } : []

        let events = showEvents ? eventService.events.filter { event in
            let eventDay = calendar.startOfDay(for: event.date)
            guard eventDay >= today else { return false }
            guard !isEventOnDate(event, date: selectedDay, calendar: calendar) else { return false }
            return matchesEventFilter(event)
        }
        .sorted { $0.date < $1.date } : []

        return (trips, events)
    }

    /// Completed trips and past events, excluding items already shown for the selected date.
    private var pastItems: (trips: [Trip], events: [Event]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: selectedDate)

        let trips = showTrips ? tripService.trips.filter { trip in
            guard trip.computedStatus == .completed else { return false }
            guard !isTripOnDate(trip, date: selectedDay, calendar: calendar) else { return false }
            return matchesTripFilter(trip)
        }
        .sorted { $0.endDate > $1.endDate } : []

        let events = showEvents ? eventService.events.filter { event in
            let eventDay = calendar.startOfDay(for: event.date)
            guard eventDay < today else { return false }
            guard !isEventOnDate(event, date: selectedDay, calendar: calendar) else { return false }
            return matchesEventFilter(event)
        }
        .sorted { $0.date > $1.date } : []

        return (trips, events)
    }

    // MARK: - Filtering Helpers

    private func isTripOnDate(_ trip: Trip, date: Date, calendar: Calendar) -> Bool {
        let tripStart = calendar.startOfDay(for: trip.startDate)
        let tripEnd = calendar.startOfDay(for: trip.endDate)
        return date >= tripStart && date <= tripEnd
    }

    private func isEventOnDate(_ event: Event, date: Date, calendar: Calendar) -> Bool {
        let eventStart = calendar.startOfDay(for: event.date)
        if let endDate = event.endDate {
            let eventEnd = calendar.startOfDay(for: endDate)
            return date >= eventStart && date <= eventEnd
        }
        return date == eventStart
    }

    private func matchesTripFilter(_ trip: Trip) -> Bool {
        guard !selectedTripStatuses.isEmpty else { return true }
        return selectedTripStatuses.contains(trip.computedStatus)
    }

    private func matchesEventFilter(_ event: Event) -> Bool {
        guard !selectedEventCategories.isEmpty else { return true }
        return selectedEventCategories.contains(event.category)
    }

    private func loadData() async {
        isLoading = true
        error = nil
        do {
            async let tripsLoad: () = tripService.loadTrips()
            async let eventsLoad: () = eventService.loadEvents()
            async let tasksLoad: () = dayPlannerService.loadData()
            _ = try await (tripsLoad, eventsLoad, tasksLoad)

            // Pre-generate routine tasks for the next 60 days so they appear on the calendar
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            for offset in 0..<60 {
                if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                    do { try await dayPlannerService.generateTasksFromRoutines(for: date) }
                    catch { print("[CalendarView] Failed to pre-generate tasks for offset \(offset): \(error)") }
                }
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

// MARK: - Month Year Picker

private struct MonthYearPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMonth: Date
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current
    private let months = Calendar.current.monthSymbols
    private let years: [Int]

    @State private var pickerMonthIndex: Int
    @State private var pickerYear: Int

    init(selectedMonth: Binding<Date>, onSelect: @escaping (Date) -> Void) {
        _selectedMonth = selectedMonth
        self.onSelect = onSelect
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        self.years = Array((currentYear - 5)...(currentYear + 5))
        _pickerMonthIndex = State(initialValue: cal.component(.month, from: selectedMonth.wrappedValue) - 1)
        _pickerYear = State(initialValue: cal.component(.year, from: selectedMonth.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Month", selection: $pickerMonthIndex) {
                    ForEach(0..<months.count, id: \.self) { index in
                        Text(months[index]).tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Year", selection: $pickerYear) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let date = calendar.date(from: DateComponents(year: pickerYear, month: pickerMonthIndex + 1)) {
                            selectedMonth = calendar.startOfMonth(for: date)
                            onSelect(date)
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

// MARK: - Navigation Destinations

private struct TripDestination: Hashable {
    let id: UUID
}

private struct EventDestination: Hashable {
    let id: UUID
}

#Preview {
    CalendarView()
        .environment(AppContainer())
        .environment(OnboardingCoordinator())
}
