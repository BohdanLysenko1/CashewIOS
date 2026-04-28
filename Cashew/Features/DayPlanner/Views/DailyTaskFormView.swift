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

    @State private var subtasks: [Subtask]
    @State private var newSubtaskTitle: String = ""

    @State private var isSaving = false
    @State private var error: String?
    @State private var showError = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title, notes, subtask
    }

    private var isEditing: Bool { task != nil }

    private var isValid: Bool {
        let hasValidTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidCustomCategory = category != .custom || !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidSchedule = !hasTime || !hasEndTime || endTime >= startTime
        return hasValidTitle && hasValidCustomCategory && hasValidSchedule
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

        _subtasks = State(initialValue: task?.subtasks ?? [])

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
        VStack(spacing: 0) {
            CreationTopBar(
                title: isEditing ? "Edit Task" : "New Task",
                subtitle: "Update schedule, context, and subtasks",
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    detailsCard
                    scheduleCard
                    categoryCard
                    linksCard
                    notesCard
                    subtasksCard
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.bottom, AppTheme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: isEditing ? "Save Task" : "Create Task",
                gradient: AppTheme.dayPlannerGradient,
                canConfirm: isValid && !isSaving,
                isLoading: isSaving,
                onCancel: { dismiss() },
                onConfirm: { Task { await save() } }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.dayPlannerGradient))
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

    private var detailsCard: some View {
        CreationSectionCard(title: "Task", icon: "checklist") {
            VStack(spacing: AppTheme.Space.md) {
                TextField("Task name", text: $title)
                    .focused($focusedField, equals: .title)
                    .designField(isFocused: focusedField == .title)

                HStack {
                    Text("Date")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurface)
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(AppTheme.primary)
                }
                .padding(.horizontal, AppTheme.Space.md)
                .padding(.vertical, AppTheme.Space.sm)
                .background(AppTheme.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
            }
        }
    }

    private var scheduleCard: some View {
        CreationSectionCard(title: "Schedule", icon: "clock") {
            VStack(spacing: AppTheme.Space.sm) {
                toggleRow("Set Time", isOn: $hasTime)

                if hasTime {
                    timeRow("Start Time", selection: $startTime)
                    toggleRow("End Time", isOn: $hasEndTime)
                    if hasEndTime {
                        timeRow("End Time", selection: $endTime, minDate: startTime)
                    }

                    CreationInlineError(
                        text: hasEndTime && endTime < startTime
                            ? "End time must be after start time"
                            : nil
                    )
                } else {
                    Text("Tasks without a time will appear in your to-do list.")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(AppTheme.TextStyle.body)
            .tint(AppTheme.primary)
            .padding(.horizontal, AppTheme.Space.md)
            .padding(.vertical, AppTheme.Space.sm)
            .background(AppTheme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
    }

    private func timeRow(_ title: String, selection: Binding<Date>, minDate: Date? = nil) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
            Spacer()
            if let minDate {
                DatePicker("", selection: selection, in: minDate..., displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(AppTheme.primary)
            } else {
                DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(AppTheme.primary)
            }
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
    }

    private var categoryCard: some View {
        CreationSectionCard(title: "Category", icon: "tag") {
            VStack(spacing: AppTheme.Space.sm) {
                HStack {
                    Text("Category")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurface)
                    Spacer()
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primary)
                }
                .padding(.horizontal, AppTheme.Space.md)
                .padding(.vertical, AppTheme.Space.sm)
                .background(AppTheme.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                if category == .custom {
                    VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                        Text("Custom Category Name")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        CustomCategoryPickerRows(
                            selectedName: $customCategoryName,
                            savedCategories: CustomCategoryStore.shared.taskCategories,
                            onDelete: { CustomCategoryStore.shared.removeTaskCategory($0) }
                        )
                    }
                    .padding(AppTheme.Space.md)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                }

                CreationInlineError(
                    text: category == .custom && customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Custom category name is required"
                        : nil
                )
            }
        }
    }

    private var linksCard: some View {
        CreationSectionCard(title: "Link To", icon: "link") {
            VStack(spacing: AppTheme.Space.sm) {
                menuRow(
                    title: "Trip",
                    selectedText: selectedTripTitle,
                    menu: {
                        Button("None") { selectedTripId = nil }
                        ForEach(tripService.trips) { trip in
                            Button(trip.name) { selectedTripId = trip.id }
                        }
                    }
                )

                menuRow(
                    title: "Event",
                    selectedText: selectedEventTitle,
                    menu: {
                        Button("None") { selectedEventId = nil }
                        ForEach(eventService.events) { event in
                            Button(event.title) { selectedEventId = event.id }
                        }
                    }
                )
            }
        }
    }

    private func menuRow<MenuContent: View>(title: String, selectedText: String, @ViewBuilder menu: () -> MenuContent) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
            Spacer()
            Menu {
                menu()
            } label: {
                HStack(spacing: 6) {
                    Text(selectedText)
                        .font(AppTheme.TextStyle.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
    }

    private var selectedTripTitle: String {
        guard let selectedTripId else { return "None" }
        return tripService.trips.first(where: { $0.id == selectedTripId })?.name ?? "None"
    }

    private var selectedEventTitle: String {
        guard let selectedEventId else { return "None" }
        return eventService.events.first(where: { $0.id == selectedEventId })?.title ?? "None"
    }

    private var notesCard: some View {
        CreationSectionCard(title: "Notes", icon: "note.text") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                if notes.isEmpty {
                    Text("Add notes...")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.6))
                        .padding(.top, 16)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var subtasksCard: some View {
        CreationSectionCard(title: "Subtasks", icon: "list.bullet") {
            VStack(spacing: AppTheme.Space.sm) {
                HStack(spacing: AppTheme.Space.sm) {
                    TextField("New subtask...", text: $newSubtaskTitle)
                        .focused($focusedField, equals: .subtask)
                        .submitLabel(.done)
                        .onSubmit { commitNewSubtask() }
                        .designField(isFocused: focusedField == .subtask)

                    Button {
                        commitNewSubtask()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AppTheme.onSurfaceVariant.opacity(0.35)
                                    : AppTheme.primary
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                ForEach($subtasks) { $subtask in
                    HStack(spacing: 12) {
                        Button {
                            subtask.isCompleted.toggle()
                            HapticManager.impact(.light)
                        } label: {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(subtask.isCompleted ? .green : AppTheme.onSurfaceVariant)
                        }
                        .buttonStyle(.plain)

                        TextField("Subtask", text: $subtask.title)
                            .strikethrough(subtask.isCompleted)
                            .foregroundStyle(subtask.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)

                        Spacer()

                        Button {
                            subtasks.removeAll { $0.id == subtask.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppTheme.Space.md)
                    .padding(.vertical, AppTheme.Space.sm)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                }

                if !subtasks.isEmpty {
                    let done = subtasks.filter(\.isCompleted).count
                    Text("\(done) of \(subtasks.count) completed")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }
        }
    }

    private func commitNewSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        subtasks.append(Subtask(title: trimmed))
        newSubtaskTitle = ""
        HapticManager.impact(.light)
    }

    private func save() async {
        isSaving = true

        do {
            let resolvedCustomName: String? = category == .custom && !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil

            if let name = resolvedCustomName {
                CustomCategoryStore.shared.addTaskCategory(name)
            }

            let newTask = DailyTask(
                id: task?.id ?? UUID(),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                startTime: hasTime ? startTime : nil,
                endTime: hasTime && hasEndTime ? endTime : nil,
                isCompleted: task?.isCompleted ?? false,
                category: category,
                customCategoryName: resolvedCustomName,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                routineId: task?.routineId,
                tripId: selectedTripId,
                eventId: selectedEventId,
                subtasks: subtasks,
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
