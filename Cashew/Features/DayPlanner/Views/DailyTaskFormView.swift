import SwiftUI

struct DailyTaskFormView: View {

    @Environment(\.dismiss) private var dismiss

    let service: DayPlannerServiceProtocol
    let tripService: TripServiceProtocol
    let eventService: EventServiceProtocol
    let task: DailyTask?

    @State private var title: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var startTime: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var category: TaskCategory
    @State private var customCategoryName: String
    @State private var notes: String
    @State private var selectedTripId: UUID?
    @State private var selectedEventId: UUID?

    @State private var isSaving = false
    @State private var error: String?
    @State private var showError = false

    private var isEditing: Bool { task != nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(
        service: DayPlannerServiceProtocol,
        tripService: TripServiceProtocol,
        eventService: EventServiceProtocol,
        task: DailyTask?,
        defaultDate: Date
    ) {
        self.service = service
        self.tripService = tripService
        self.eventService = eventService
        self.task = task

        if let task {
            _title = State(initialValue: task.title)
            _date = State(initialValue: task.date)
            _hasTime = State(initialValue: task.startTime != nil)
            _startTime = State(initialValue: task.startTime ?? Date())
            _hasEndTime = State(initialValue: task.endTime != nil)
            _endTime = State(initialValue: task.endTime ?? Date().addingTimeInterval(3600))
            _category = State(initialValue: task.category)
            _customCategoryName = State(initialValue: task.customCategoryName ?? "")
            _notes = State(initialValue: task.notes)
            _selectedTripId = State(initialValue: task.tripId)
            _selectedEventId = State(initialValue: task.eventId)
        } else {
            _title = State(initialValue: "")
            _date = State(initialValue: defaultDate)
            _hasTime = State(initialValue: false)
            // Default start time to next hour
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            let defaultStart = calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: Date()) ?? Date()
            _startTime = State(initialValue: defaultStart)
            _hasEndTime = State(initialValue: false)
            _endTime = State(initialValue: defaultStart.addingTimeInterval(3600))
            _category = State(initialValue: .personal)
            _customCategoryName = State(initialValue: "")
            _notes = State(initialValue: "")
            _selectedTripId = State(initialValue: nil)
            _selectedEventId = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                scheduleSection
                categorySection
                linkSection
                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    savingOverlay
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { error = nil }
            } message: {
                if let error {
                    Text(error)
                }
            }
            .task {
                if tripService.trips.isEmpty {
                    do { try await tripService.loadTrips() }
                    catch { print("[DailyTaskFormView] Failed to load trips: \(error)") }
                }
                if eventService.events.isEmpty {
                    do { try await eventService.loadEvents() }
                    catch { print("[DailyTaskFormView] Failed to load events: \(error)") }
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            TextField("Task name", text: $title)
        } header: {
            Text("Task")
        }
    }

    private var scheduleSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)

            Toggle("Set Time", isOn: $hasTime)

            if hasTime {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                Toggle("End Time", isOn: $hasEndTime)

                if hasEndTime {
                    DatePicker("End Time", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            if !hasTime {
                Text("Tasks without a time will appear in your to-do list")
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $category) {
                ForEach(TaskCategory.allCases, id: \.self) { cat in
                    Label(cat.displayName, systemImage: cat.icon)
                        .tag(cat)
                }
            }
            .pickerStyle(.navigationLink)

            if category == .custom {
                CustomCategoryPickerRows(
                    selectedName: $customCategoryName,
                    savedCategories: CustomCategoryStore.shared.taskCategories,
                    onDelete: { CustomCategoryStore.shared.removeTaskCategory($0) }
                )
            }
        }
    }

    private var linkSection: some View {
        Section("Link To") {
            Picker("Trip", selection: $selectedTripId) {
                Text("None")
                    .tag(UUID?.none)

                ForEach(tripService.trips) { trip in
                    Label(trip.name, systemImage: "airplane")
                        .tag(Optional(trip.id))
                }
            }

            Picker("Event", selection: $selectedEventId) {
                Text("None")
                    .tag(UUID?.none)

                ForEach(eventService.events) { event in
                    Label(event.title, systemImage: "star")
                        .tag(Optional(event.id))
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Add notes...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            ProgressView("Saving...")
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true

        do {
            let resolvedCustomName: String? = category == .custom && !customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty
                ? customCategoryName.trimmingCharacters(in: .whitespaces)
                : nil

            if let name = resolvedCustomName {
                CustomCategoryStore.shared.addTaskCategory(name)
            }

            let newTask = DailyTask(
                id: task?.id ?? UUID(),
                title: title.trimmingCharacters(in: .whitespaces),
                date: date,
                startTime: hasTime ? startTime : nil,
                endTime: hasTime && hasEndTime ? endTime : nil,
                isCompleted: task?.isCompleted ?? false,
                category: category,
                customCategoryName: resolvedCustomName,
                notes: notes,
                routineId: task?.routineId,
                tripId: selectedTripId,
                eventId: selectedEventId,
                createdAt: task?.createdAt ?? Date()
            )

            if isEditing {
                try await service.updateTask(newTask)
            } else {
                try await service.createTask(newTask)
            }

            dismiss()
        } catch {
            self.error = error.localizedDescription
            showError = true
        }

        isSaving = false
    }
}

#Preview("New Task") {
    let container = AppContainer()
    DailyTaskFormView(
        service: container.dayPlannerService,
        tripService: container.tripService,
        eventService: container.eventService,
        task: nil,
        defaultDate: Date()
    )
}

#Preview("Edit Task") {
    let container = AppContainer()
    DailyTaskFormView(
        service: container.dayPlannerService,
        tripService: container.tripService,
        eventService: container.eventService,
        task: DailyTask(
            title: "Team Meeting",
            date: Date(),
            startTime: Date(),
            category: .work
        ),
        defaultDate: Date()
    )
}
