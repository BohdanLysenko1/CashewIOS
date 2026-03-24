import SwiftUI

struct EventFormView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EventFormViewModel
    @State private var showError = false
    @State private var showAddReminder = false
    @State private var showAddLink = false

    init(viewModel: EventFormViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                dateTimeSection
                recurrenceSection
                remindersSection
                categoryAndPrioritySection
                linksSection
                PhotosPickerSection(photoAttachments: $viewModel.photoAttachments)
                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isEditing ? "Save" : "Add") {
                        Task { await viewModel.save() }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    savingOverlay
                }
            }
            .onChange(of: viewModel.error) { _, newError in
                showError = newError != nil
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
            .onChange(of: viewModel.didSave) { _, didSave in
                if didSave {
                    dismiss()
                }
            }
            .sheet(isPresented: $showAddReminder) {
                AddReminderSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showAddLink) {
                AddLinkSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            TextField("Event Title", text: $viewModel.title)

            LocationSearchField(
                text: $viewModel.location,
                latitude: $viewModel.locationLatitude,
                longitude: $viewModel.locationLongitude,
                label: "Location",
                placeholder: "Search for a place..."
            )

            TextField("Address (optional)", text: $viewModel.address)
                .textContentType(.fullStreetAddress)
        } header: {
            Text("Details")
        } footer: {
            if let error = viewModel.titleError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Date & Time Section

    private var dateTimeSection: some View {
        Section {
            Toggle("All Day", isOn: $viewModel.isAllDay)

            if viewModel.isAllDay {
                DatePicker(
                    "Date",
                    selection: $viewModel.date,
                    displayedComponents: .date
                )
            } else {
                DatePicker(
                    "Starts",
                    selection: $viewModel.date,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Toggle("End Time", isOn: $viewModel.hasEndDate)

                if viewModel.hasEndDate {
                    DatePicker(
                        "Ends",
                        selection: Binding(
                            get: { viewModel.endDate ?? viewModel.date.addingTimeInterval(3600) },
                            set: { viewModel.endDate = $0 }
                        ),
                        in: viewModel.date...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
        } header: {
            Text("Date & Time")
        } footer: {
            if let error = viewModel.dateError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
        Section {
            Toggle("Repeat", isOn: $viewModel.isRecurring)

            if viewModel.isRecurring {
                Picker("Frequency", selection: $viewModel.recurrenceFrequency) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }

                Stepper("Every \(viewModel.recurrenceInterval) \(viewModel.recurrenceFrequency.pluralName)",
                        value: $viewModel.recurrenceInterval, in: 1...30)

                if viewModel.recurrenceFrequency == .weekly {
                    NavigationLink {
                        DayOfWeekPicker(selectedDays: $viewModel.selectedDaysOfWeek)
                    } label: {
                        HStack {
                            Text("Days")
                            Spacer()
                            Text(selectedDaysText)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                        }
                    }
                }

                Toggle("End Date", isOn: $viewModel.hasRecurrenceEndDate)

                if viewModel.hasRecurrenceEndDate {
                    DatePicker(
                        "Ends On",
                        selection: Binding(
                            get: { viewModel.recurrenceEndDate ?? viewModel.date.addingTimeInterval(86400 * 30) },
                            set: { viewModel.recurrenceEndDate = $0 }
                        ),
                        in: viewModel.date...,
                        displayedComponents: .date
                    )
                }
            }
        } header: {
            Text("Repeat")
        }
    }

    private var selectedDaysText: String {
        if viewModel.selectedDaysOfWeek.isEmpty {
            return "None"
        }
        if viewModel.selectedDaysOfWeek.count == 7 {
            return "Every day"
        }
        return viewModel.selectedDaysOfWeek
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.shortName }
            .joined(separator: ", ")
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        Section {
            ForEach(viewModel.reminders) { reminder in
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.orange)
                    Text(reminder.interval.displayName)
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.removeReminder(reminder)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                showAddReminder = true
            } label: {
                Label("Add Reminder", systemImage: "plus.circle")
            }
        } header: {
            Text("Reminders")
        }
    }

    // MARK: - Category & Priority Section

    private var categoryAndPrioritySection: some View {
        Section {
            Picker("Category", selection: $viewModel.category) {
                ForEach(EventCategory.allCases, id: \.self) { category in
                    Label(category.displayName, systemImage: category.icon)
                        .foregroundStyle(category.color)
                        .tag(category)
                }
            }
            .pickerStyle(.navigationLink)

            if viewModel.category == .custom {
                CustomCategoryPickerRows(
                    selectedName: $viewModel.customCategoryName,
                    savedCategories: CustomCategoryStore.shared.eventCategories,
                    onDelete: { CustomCategoryStore.shared.removeEventCategory($0) }
                )
            }

            Picker("Priority", selection: $viewModel.priority) {
                ForEach(EventPriority.allCases, id: \.self) { priority in
                    Label(priority.displayName, systemImage: priority.icon)
                        .tag(priority)
                }
            }
        } header: {
            Text("Category & Priority")
        }
    }

    // MARK: - Links Section

    private var linksSection: some View {
        Section {
            TextField("Website URL (optional)", text: $viewModel.urlString)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)

            HStack {
                Text(viewModel.currency)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                TextField("Cost (optional)", text: $viewModel.costString)
                    .keyboardType(.decimalPad)
            }

            if !viewModel.attachments.isEmpty {
                ForEach(viewModel.attachments) { attachment in
                    HStack {
                        Image(systemName: attachment.type.icon)
                            .foregroundStyle(.blue)
                        Text(attachment.name)
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.removeAttachment(attachment)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                showAddLink = true
            } label: {
                Label("Add Link", systemImage: "link.badge.plus")
            }
        } header: {
            Text("Links & Cost")
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        Section("Notes") {
            TextField("Add notes...", text: $viewModel.notes, axis: .vertical)
                .lineLimit(4...8)
        }
    }

    // MARK: - Saving Overlay

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
}

// MARK: - Day of Week Picker

struct DayOfWeekPicker: View {
    @Binding var selectedDays: Set<DayOfWeek>

    var body: some View {
        List {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                Button {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    HStack {
                        Text(day.displayName)
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        if selectedDays.contains(day) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Days")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add Reminder Sheet

struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: EventFormViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(ReminderInterval.allCases, id: \.self) { interval in
                    let isAdded = viewModel.reminders.contains { $0.interval == interval }

                    Button {
                        if !isAdded {
                            viewModel.addReminder(interval)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(interval.displayName)
                                .foregroundStyle(isAdded ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                            Spacer()
                            if isAdded {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(isAdded)
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add Link Sheet

struct AddLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: EventFormViewModel

    @State private var name: String = ""
    @State private var urlString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Link Name", text: $name)
                TextField("URL", text: $urlString)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addLinkAttachment(name: name, urlString: urlString)
                        dismiss()
                    }
                    .disabled(name.isEmpty || urlString.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("New Event") {
    EventFormView(
        viewModel: EventFormViewModel(
            eventService: EventService(repository: LocalEventRepository())
        )
    )
}

#Preview("Edit Event") {
    EventFormView(
        viewModel: EventFormViewModel(
            eventService: EventService(repository: LocalEventRepository()),
            event: Event(
                title: "Team Meeting",
                date: Date(),
                location: "Conference Room A",
                category: .meeting
            )
        )
    )
}
