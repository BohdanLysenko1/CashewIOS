import SwiftUI

struct TripItineraryView: View {
    @Binding var trip: Trip
    let initialIntent: TripSectionIntent
    @State private var selectedDate: Date
    @State private var showAddActivity = false
    @State private var editingActivity: Activity?
    @State private var showBookedOnly = false
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

    var body: some View {
        VStack(spacing: 0) {
            dateSelector

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    summaryCard

                    let activities = displayedActivities
                    if activities.isEmpty {
                        emptyDayView
                    } else {
                        dayScheduleView(activities: activities)
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }
            .background(AppTheme.background)
        }
        .navigationTitle("Itinerary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddActivity = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddActivity) {
            ActivityFormView(trip: $trip, activity: nil, defaultDate: selectedDate)
        }
        .sheet(item: $editingActivity) { activity in
            ActivityFormView(trip: $trip, activity: activity, defaultDate: selectedDate)
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

            Button {
                showAddActivity = true
            } label: {
                Label("Add Activity", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(AppTheme.Space.lg)
        .tripModuleCard()
    }

    // MARK: - Day Schedule

    private func dayScheduleView(activities: [Activity]) -> some View {
        TripSectionCard("Timeline", icon: "clock.badge.checkmark") {
            VStack(spacing: AppTheme.Space.sm) {
                ForEach(activities) { activity in
                    ActivityCard(activity: activity) {
                        editingActivity = activity
                    } onDelete: {
                        deleteActivity(activity)
                    }
                }
            }
        }
    }

    private func deleteActivity(_ activity: Activity) {
        trip.activities.removeAll { $0.id == activity.id }
    }

    private func applyInitialIntentIfNeeded() {
        guard !didApplyInitialIntent else { return }
        didApplyInitialIntent = true

        if initialIntent == .addActivity {
            showAddActivity = true
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
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? .white.opacity(0.36) : AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: isSelected ? AppTheme.secondary.opacity(0.22) : .clear, radius: 12, x: 0, y: 4)
    }
}

// MARK: - Activity Card

private struct ActivityCard: View {
    let activity: Activity
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Activity Name", text: $title)

                    Picker("Type", selection: $category) {
                        ForEach(ActivityCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Toggle("Set Time", isOn: $hasTime)

                    if hasTime {
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                        Toggle("End Time", isOn: $hasEndTime)

                        if hasEndTime {
                            DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                Section("Location") {
                    TextField("Place Name", text: $location)
                    TextField("Address", text: $address)
                }

                Section("Booking") {
                    Toggle("Booked", isOn: $isBooked)

                    if isBooked {
                        TextField("Confirmation #", text: $confirmationNumber)
                    }

                    HStack {
                        Text(trip.currency)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        TextField("Cost (optional)", text: $costString)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(activity == nil ? "Add Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveActivity()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
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
