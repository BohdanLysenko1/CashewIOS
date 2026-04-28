import SwiftUI
import MapKit

struct TripItineraryView: View {
    @Binding var trip: Trip
    let initialIntent: TripSectionIntent
    @State private var selectedDate: Date
    @State private var showAddActivity = false
    @State private var showAIGenerator = false
    @State private var showBudgetFromAI = false
    @State private var editingActivity: Activity?
    @State private var showBookedOnly = false
    @State private var selectedActivity: Activity?
    @State private var showShareSheet = false
    @State private var didApplyInitialIntent = false

    init(trip: Binding<Trip>, initialIntent: TripSectionIntent = .overview) {
        self._trip = trip
        self.initialIntent = initialIntent
        self._selectedDate = State(initialValue: trip.wrappedValue.startDate)
    }

    private var tripDates: [Date] {
        var dates: [Date] = []
        var current = trip.startDate
        let calendar = Calendar.current

        while current <= trip.endDate {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
        }
        return dates
    }

    private var mappableActivities: [Activity] {
        displayedActivities.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            dateSelector

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    if !mappableActivities.isEmpty {
                        ItineraryMapView(activities: mappableActivities) { activity in
                            selectedActivity = activity
                        }
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                            .padding(.horizontal, AppTheme.Space.lg)
                    }

                    summaryCard

                    if trip.activities.isEmpty {
                        aiPromptCard
                    } else {
                        let activities = displayedActivities
                        if activities.isEmpty {
                            emptyDayView
                        } else {
                            dayScheduleView(activities: activities)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }
            .background(AppTheme.background)
        }
        .navigationTitle("Itinerary")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !trip.activities.isEmpty {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Button {
                    showAIGenerator = true
                } label: {
                    Image(systemName: "sparkles")
                }
                Button {
                    showAddActivity = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [formatItineraryForShare()])
        }
        .sheet(isPresented: $showAddActivity) {
            ActivityFormView(trip: $trip, activity: nil, defaultDate: selectedDate)
        }
        .sheet(item: $editingActivity) { activity in
            ActivityFormView(trip: $trip, activity: activity, defaultDate: selectedDate)
        }
        .sheet(isPresented: $showAIGenerator) {
            AIItineraryView(trip: $trip) {
                showBudgetFromAI = true
            }
        }
        .sheet(isPresented: $showBudgetFromAI) {
            TripBudgetView(trip: $trip, initialIntent: .addExpense)
        }
        .sheet(item: $selectedActivity) { activity in
            ActivityDetailView(activity: activity, trip: $trip)
        }
        .onAppear {
            applyInitialIntentIfNeeded()
        }
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tripDates, id: \.self) { date in
                        DateTab(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            activityCount: trip.activitiesForDate(date).count
                        )
                        .id(date)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedDate = date
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }
            .background(AppTheme.background)
            .onAppear {
                proxy.scrollTo(selectedDate, anchor: .center)
            }
        }
    }

    private var displayedActivities: [Activity] {
        let base = trip.activitiesForDate(selectedDate)
        if !showBookedOnly { return base }
        return base.filter(\.isBooked)
    }

    private var summaryCard: some View {
        TripHeroCard(
            icon: "calendar.day.timeline.left",
            title: selectedDate.formatted(date: .abbreviated, time: .omitted),
            subtitle: "\(displayedActivities.count) \(displayedActivities.count == 1 ? "activity" : "activities") planned"
        ) {
            HStack(spacing: AppTheme.Space.sm) {
                TripMetricPill(label: "Booked", value: "\(displayedActivities.filter(\.isBooked).count)")
                TripMetricPill(label: "Flexible", value: "\(displayedActivities.filter { !$0.isBooked }.count)")
                Spacer(minLength: 0)
            }

            Toggle(isOn: $showBookedOnly) {
                Text("Booked activities only")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .tint(.white.opacity(0.92))
        }
    }

    // MARK: - Empty Day View

    private var emptyDayView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.onSurfaceVariant)

            VStack(spacing: 6) {
                Text("No Activities")
                    .font(.headline)

                Text("Plan activities for this day")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            HStack(spacing: AppTheme.Space.sm) {
                Button {
                    showAddActivity = true
                } label: {
                    Label("Add Activity", systemImage: "plus")
                        .primaryActionButton(gradient: AppTheme.tripGradient, fullWidth: false)
                }
                .buttonStyle(.plain)

                Button {
                    showAIGenerator = true
                } label: {
                    Label("Generate with AI", systemImage: "sparkles")
                        .secondaryActionButton(fullWidth: false)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }

    // MARK: - AI Prompt Card

    private var aiPromptCard: some View {
        VStack(spacing: AppTheme.Space.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.tripGradient)

            VStack(spacing: 6) {
                Text("Plan Your Itinerary with AI")
                    .font(.headline)

                Text("Let Gemini create a personalized day-by-day itinerary based on your interests and budget")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Label(
                    "\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
                .font(AppTheme.TextStyle.caption)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(Capsule())
            }

            Button {
                showAIGenerator = true
            } label: {
                Label("Generate AI Itinerary", systemImage: "sparkles")
                    .primaryActionButton(gradient: AppTheme.tripGradient)
            }
            .buttonStyle(.plain)

            Button {
                showAddActivity = true
            } label: {
                Text("or add activities manually")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, AppTheme.Space.lg)
        .tripModuleCard()
    }

    // MARK: - Day Schedule

    private func dayScheduleView(activities: [Activity]) -> some View {
        TripSectionCard("Timeline", icon: "clock.badge.checkmark") {
            VStack(spacing: AppTheme.Space.sm) {
                ForEach(activities) { activity in
                    ActivityCard(activity: activity) {
                        selectedActivity = activity
                    } onEdit: {
                        editingActivity = activity
                    } onDelete: {
                        deleteActivity(activity)
                    }
                }
                .onMove { source, destination in
                    moveActivities(from: source, to: destination)
                }
            }
        }
    }

    private func moveActivities(from source: IndexSet, to destination: Int) {
        var dayActivities = displayedActivities
        dayActivities.move(fromOffsets: source, toOffset: destination)

        // Update sortOrder for all reordered activities
        for (index, activity) in dayActivities.enumerated() {
            if let tripIndex = trip.activities.firstIndex(where: { $0.id == activity.id }) {
                trip.activities[tripIndex].sortOrder = index
            }
        }
    }

    private func deleteActivity(_ activity: Activity) {
        trip.activities.removeAll { $0.id == activity.id }
    }

    private func formatItineraryForShare() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        var lines: [String] = []
        lines.append("\(trip.name) — Itinerary")
        lines.append("\(trip.destination)")
        lines.append("\(trip.startDate.formatted(date: .long, time: .omitted)) – \(trip.endDate.formatted(date: .long, time: .omitted))")
        lines.append("")

        for date in tripDates {
            let dayActivities = trip.activitiesForDate(date)
            guard !dayActivities.isEmpty else { continue }

            lines.append(date.formatted(date: .long, time: .omitted))
            lines.append(String(repeating: "─", count: 30))

            for activity in dayActivities {
                var timeStr = ""
                if let start = activity.startTime {
                    timeStr = timeFormatter.string(from: start)
                    if let end = activity.endTime {
                        timeStr += " – \(timeFormatter.string(from: end))"
                    }
                    timeStr += "  "
                }
                let location = activity.location.isEmpty ? "" : " @ \(activity.location)"
                lines.append("\(timeStr)\(activity.title) (\(activity.category.displayName))\(location)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func applyInitialIntentIfNeeded() {
        guard !didApplyInitialIntent else { return }
        didApplyInitialIntent = true

        switch initialIntent {
        case .addActivity:
            showAddActivity = true
        case .generateAI:
            showAIGenerator = true
        default:
            break
        }
    }
}

// MARK: - Date Tab

private struct DateTab: View {
    let date: Date
    let isSelected: Bool
    let activityCount: Int

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    var body: some View {
        VStack(spacing: 5) {
            Text(Self.dayFormatter.string(from: date))
                .font(AppTheme.TextStyle.captionBold)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : AppTheme.onSurfaceVariant)

            Text(Self.dateFormatter.string(from: date))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .white : AppTheme.onSurface)

            if activityCount > 0 {
                Text("\(activityCount)")
                    .font(AppTheme.TextStyle.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : AppTheme.secondary)
            }
        }
        .frame(width: 58, height: 78)
        .background(isSelected ? AnyShapeStyle(AppTheme.tripGradient) : AnyShapeStyle(AppTheme.surfaceContainerLow))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous)
                .strokeBorder(isSelected ? .white.opacity(0.36) : AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: isSelected ? AppTheme.secondary.opacity(0.22) : .clear, radius: 12, x: 0, y: 4)
    }
}

// MARK: - Activity Card

private struct ActivityCard: View {
    let activity: Activity
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                if let startTime = activity.startTime {
                    Text(Self.timeFormatter.string(from: startTime))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let endTime = activity.endTime {
                        Text(Self.timeFormatter.string(from: endTime))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                } else {
                    Text("Any time")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .lineLimit(1)
                }
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(AppTheme.secondary.opacity(0.55))
                    .padding(.top, 2)
            }
            .frame(width: 58, alignment: .trailing)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: activity.category.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(activity.category.color.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(activity.category.displayName)
                            .font(.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }

                    Spacer()

                    if activity.isBooked {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                if !activity.location.isEmpty {
                    Label(activity.location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }

                if let cost = activity.cost {
                    Label(formatCost(cost, currency: activity.currency), systemImage: "creditcard")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }

                if !activity.notes.isEmpty {
                    Text(activity.notes)
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tripSoftSurface()
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }


    private func formatCost(_ cost: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: cost as NSNumber) ?? "\(currency) \(cost)"
    }
}

// MARK: - Activity Form

struct ActivityFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip

    let activity: Activity?
    let defaultDate: Date

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var hasTime = false
    @State private var startTime: Date = Date()
    @State private var hasEndTime = false
    @State private var endTime: Date = Date()
    @State private var location: String = ""
    @State private var address: String = ""
    @State private var category: ActivityCategory = .activity
    @State private var notes: String = ""
    @State private var costString: String = ""
    @State private var isBooked = false
    @State private var confirmationNumber: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case title, location, address, confirmation, cost, notes }

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: activity == nil ? "Add Activity" : "Edit Activity",
                subtitle: nil,
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    // Activity details
                    CreationSectionCard(title: "Activity", icon: "star") {
                        VStack(spacing: AppTheme.Space.sm) {
                            TextField("Activity Name", text: $title)
                                .focused($focusedField, equals: .title)
                                .designField(isFocused: focusedField == .title)

                            HStack {
                                Text("Type")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                Picker("Type", selection: $category) {
                                    ForEach(ActivityCategory.allCases, id: \.self) { cat in
                                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.secondary)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                        }
                    }

                    // When
                    CreationSectionCard(title: "When", icon: "calendar") {
                        VStack(spacing: AppTheme.Space.sm) {
                            HStack {
                                Text("Date")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(AppTheme.secondary)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                            Toggle("Set Time", isOn: $hasTime)
                                .font(AppTheme.TextStyle.body)
                                .tint(AppTheme.secondary)
                                .padding(.horizontal, AppTheme.Space.md)
                                .padding(.vertical, AppTheme.Space.sm)
                                .background(AppTheme.surfaceContainer)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                            if hasTime {
                                HStack {
                                    Text("Start Time")
                                        .font(AppTheme.TextStyle.body)
                                        .foregroundStyle(AppTheme.onSurface)
                                    Spacer()
                                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .tint(AppTheme.secondary)
                                }
                                .padding(.horizontal, AppTheme.Space.md)
                                .padding(.vertical, AppTheme.Space.sm)
                                .background(AppTheme.surfaceContainer)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                                Toggle("End Time", isOn: $hasEndTime)
                                    .font(AppTheme.TextStyle.body)
                                    .tint(AppTheme.secondary)
                                    .padding(.horizontal, AppTheme.Space.md)
                                    .padding(.vertical, AppTheme.Space.sm)
                                    .background(AppTheme.surfaceContainer)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                                if hasEndTime {
                                    HStack {
                                        Text("End Time")
                                            .font(AppTheme.TextStyle.body)
                                            .foregroundStyle(AppTheme.onSurface)
                                        Spacer()
                                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .tint(AppTheme.secondary)
                                    }
                                    .padding(.horizontal, AppTheme.Space.md)
                                    .padding(.vertical, AppTheme.Space.sm)
                                    .background(AppTheme.surfaceContainer)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                                }
                            }
                        }
                    }

                    // Location
                    CreationSectionCard(title: "Location", icon: "mappin") {
                        VStack(spacing: AppTheme.Space.sm) {
                            TextField("Place Name", text: $location)
                                .focused($focusedField, equals: .location)
                                .designField(isFocused: focusedField == .location)

                            TextField("Address", text: $address)
                                .focused($focusedField, equals: .address)
                                .designField(isFocused: focusedField == .address)
                        }
                    }

                    // Booking
                    CreationSectionCard(title: "Booking", icon: "checkmark.seal") {
                        VStack(spacing: AppTheme.Space.sm) {
                            Toggle("Booked", isOn: $isBooked)
                                .font(AppTheme.TextStyle.body)
                                .tint(AppTheme.secondary)
                                .padding(.horizontal, AppTheme.Space.md)
                                .padding(.vertical, AppTheme.Space.sm)
                                .background(AppTheme.surfaceContainer)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                            if isBooked {
                                TextField("Confirmation #", text: $confirmationNumber)
                                    .focused($focusedField, equals: .confirmation)
                                    .designField(isFocused: focusedField == .confirmation)
                            }

                            HStack(spacing: AppTheme.Space.sm) {
                                Text(trip.currency)
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                                    .padding(.leading, 14)
                                TextField("Cost (optional)", text: $costString)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .cost)
                            }
                            .padding(.vertical, 14)
                            .background(focusedField == .cost ? AppTheme.surfaceContainerLowest : AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                    .stroke(focusedField == .cost ? AppTheme.primary.opacity(0.20) : .clear, lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.2), value: focusedField == .cost)
                        }
                    }

                    // Notes
                    CreationSectionCard(title: "Notes", icon: "note.text") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .focused($focusedField, equals: .notes)
                            .designField(isFocused: focusedField == .notes)
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.bottom, AppTheme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: activity == nil ? "Add Activity" : "Save Activity",
                gradient: AppTheme.tripGradient,
                canConfirm: !title.isEmpty,
                isLoading: false,
                onCancel: { dismiss() },
                onConfirm: { saveActivity(); dismiss() }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .onAppear {
            if let activity {
                title = activity.title
                date = activity.date
                hasTime = activity.startTime != nil
                startTime = activity.startTime ?? Date()
                hasEndTime = activity.endTime != nil
                endTime = activity.endTime ?? Date()
                location = activity.location
                address = activity.address
                category = activity.category
                notes = activity.notes
                isBooked = activity.isBooked
                confirmationNumber = activity.confirmationNumber
                if let cost = activity.cost {
                    costString = "\(cost)"
                }
            } else {
                date = defaultDate
            }
        }
    }

    private func saveActivity() {
        let cost = Decimal(string: costString)

        if let activity {
            if let index = trip.activities.firstIndex(where: { $0.id == activity.id }) {
                trip.activities[index].title = title
                trip.activities[index].date = date
                trip.activities[index].startTime = hasTime ? startTime : nil
                trip.activities[index].endTime = hasTime && hasEndTime ? endTime : nil
                trip.activities[index].location = location
                trip.activities[index].address = address
                trip.activities[index].category = category
                trip.activities[index].notes = notes
                trip.activities[index].cost = cost
                trip.activities[index].isBooked = isBooked
                trip.activities[index].confirmationNumber = confirmationNumber
            }
        } else {
            let newActivity = Activity(
                title: title,
                date: date,
                startTime: hasTime ? startTime : nil,
                endTime: hasTime && hasEndTime ? endTime : nil,
                location: location,
                address: address,
                notes: notes,
                category: category,
                cost: cost,
                currency: trip.currency,
                isBooked: isBooked,
                confirmationNumber: confirmationNumber
            )
            trip.activities.append(newActivity)
        }
    }
}

// MARK: - Itinerary Map View

private struct ItineraryMapView: View {
    let activities: [Activity]
    var onPinTapped: ((Activity) -> Void)?

    @State private var cameraPos: MapCameraPosition = .automatic

    private var computedPosition: MapCameraPosition {
        let coords = activities.compactMap { a -> CLLocationCoordinate2D? in
            guard let lat = a.latitude, let lon = a.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return .automatic }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let centerLat = (lats.max()! + lats.min()!) / 2
        let centerLon = (lons.max()! + lons.min()!) / 2
        let spanLat = max((lats.max()! - lats.min()!) * 1.5, 0.02)
        let spanLon = max((lons.max()! - lons.min()!) * 1.5, 0.02)

        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        ))
    }

    private var polylineCoords: [CLLocationCoordinate2D] {
        activities.compactMap { a in
            guard let lat = a.latitude, let lon = a.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    var body: some View {
        Map(position: $cameraPos) {
            if polylineCoords.count > 1 {
                MapPolyline(coordinates: polylineCoords)
                    .stroke(
                        AppTheme.secondary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                MapPolyline(coordinates: polylineCoords)
                    .stroke(
                        AppTheme.tripGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
            }
            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                if let lat = activity.latitude, let lon = activity.longitude {
                    Annotation(
                        activity.title,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        anchor: .bottom
                    ) {
                        Button {
                            onPinTapped?(activity)
                        } label: {
                            NumberedMapPin(index: index + 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(activity.title)
                    }
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .onAppear { cameraPos = computedPosition }
        .onChange(of: activities) { _, _ in cameraPos = computedPosition }
        .overlay {
            LinearGradient(
                colors: [
                    AppTheme.secondary.opacity(0.22),
                    .clear,
                    AppTheme.primary.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("Route View")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.scrim)
            )
            .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(activities.count) stops")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.secondary.opacity(0.85))
                )
                .padding(12)
        }
    }
}

#Preview {
    NavigationStack {
        TripItineraryView(trip: .constant(Trip(
            name: "Paris Trip",
            destination: "Paris, France",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 5),
            activities: [
                Activity(title: "Flight to Paris", date: Date(), startTime: Date(), location: "", category: .flight, isBooked: true),
                Activity(title: "Eiffel Tower", date: Date(), startTime: Date().addingTimeInterval(3600 * 4), location: "Eiffel Tower", category: .tour)
            ]
        )))
    }
}
