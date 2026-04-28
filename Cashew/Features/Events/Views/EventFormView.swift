import SwiftUI

struct EventFormView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EventFormViewModel
    @State private var showError = false
    @State private var newLinkName = ""
    @State private var newLinkURL = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title, address, url, cost, notes, linkName, linkURL
    }

    init(viewModel: EventFormViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CreationTopBar(
                    title: viewModel.isEditing ? "Edit Event" : "New Event",
                    subtitle: "Refine schedule, reminders, and details",
                    onClose: { dismiss() }
                )

                ScrollView {
                    VStack(spacing: AppTheme.Space.md) {
                        detailsCard
                        dateTimeCard
                        recurrenceCard
                        remindersCard
                        categoryPriorityCard
                        linksCostCard
                        photosCard
                        notesCard
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.bottom, AppTheme.Space.xxxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                CreationBottomActionBar(
                    cancelTitle: "Cancel",
                    confirmTitle: viewModel.isEditing ? "Save Event" : "Create Event",
                    gradient: AppTheme.eventGradient,
                    canConfirm: viewModel.isValid,
                    isLoading: viewModel.isSaving,
                    onCancel: { dismiss() },
                    onConfirm: { Task { await viewModel.save() } }
                )
            }
            .background(CreationScreenBackground(gradient: AppTheme.eventGradient))
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
        }
    }

    private var detailsCard: some View {
        CreationSectionCard(title: "Details", icon: "star") {
            VStack(spacing: AppTheme.Space.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Event Title")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    TextField("e.g. Product Kickoff", text: $viewModel.title)
                        .focused($focusedField, equals: .title)
                        .designField(isFocused: focusedField == .title)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Location")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    LocationSearchField(
                        text: $viewModel.location,
                        latitude: $viewModel.locationLatitude,
                        longitude: $viewModel.locationLongitude,
                        label: "Location",
                        placeholder: "Search for a place..."
                    )
                    .padding(.horizontal, AppTheme.Space.md)
                    .padding(.vertical, AppTheme.Space.sm)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                }

                TextField("Address (optional)", text: $viewModel.address)
                    .focused($focusedField, equals: .address)
                    .textContentType(.fullStreetAddress)
                    .designField(isFocused: focusedField == .address)

                CreationInlineError(text: viewModel.titleError)
            }
        }
    }

    private var dateTimeCard: some View {
        CreationSectionCard(title: "Date & Time", icon: "calendar") {
            VStack(spacing: AppTheme.Space.sm) {
                toggleRow("All Day", isOn: $viewModel.isAllDay)

                if viewModel.isAllDay {
                    dateRow("Date", selection: $viewModel.date, components: .date)
                } else {
                    dateRow("Starts", selection: $viewModel.date, components: [.date, .hourAndMinute])
                    toggleRow("End Time", isOn: $viewModel.hasEndDate)
                    if viewModel.hasEndDate {
                        dateRow("Ends", selection: Binding(
                            get: { viewModel.endDate ?? viewModel.date.addingTimeInterval(3600) },
                            set: { viewModel.endDate = $0 }
                        ), components: [.date, .hourAndMinute], minDate: viewModel.date)
                    }
                }

                CreationInlineError(text: viewModel.dateError)
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(AppTheme.TextStyle.body)
            .tint(AppTheme.tertiary)
            .padding(.horizontal, AppTheme.Space.md)
            .padding(.vertical, AppTheme.Space.sm)
            .background(AppTheme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
    }

    private func dateRow(
        _ title: String,
        selection: Binding<Date>,
        components: DatePickerComponents,
        minDate: Date? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
            Spacer()
            if let minDate {
                DatePicker("", selection: selection, in: minDate..., displayedComponents: components)
                    .labelsHidden()
                    .tint(AppTheme.tertiary)
            } else {
                DatePicker("", selection: selection, displayedComponents: components)
                    .labelsHidden()
                    .tint(AppTheme.tertiary)
            }
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
    }

    private var recurrenceCard: some View {
        CreationSectionCard(title: "Repeat", icon: "repeat") {
            VStack(spacing: AppTheme.Space.sm) {
                toggleRow("Repeat Event", isOn: $viewModel.isRecurring)

                if viewModel.isRecurring {
                    pickerRow(title: "Frequency") {
                        Picker("Frequency", selection: $viewModel.recurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Stepper(
                        "Every \(viewModel.recurrenceInterval) \(viewModel.recurrenceFrequency.pluralName)",
                        value: $viewModel.recurrenceInterval,
                        in: 1...30
                    )
                    .padding(.horizontal, AppTheme.Space.md)
                    .padding(.vertical, AppTheme.Space.sm)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                    if viewModel.recurrenceFrequency == .weekly {
                        NavigationLink {
                            DayOfWeekPicker(selectedDays: $viewModel.selectedDaysOfWeek)
                        } label: {
                            HStack {
                                Text("Days")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                Text(selectedDaysText)
                                    .font(AppTheme.TextStyle.secondary)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    toggleRow("End Date", isOn: $viewModel.hasRecurrenceEndDate)
                    if viewModel.hasRecurrenceEndDate {
                        dateRow(
                            "Ends On",
                            selection: Binding(
                                get: { viewModel.recurrenceEndDate ?? viewModel.date.addingTimeInterval(86400 * 30) },
                                set: { viewModel.recurrenceEndDate = $0 }
                            ),
                            components: .date,
                            minDate: viewModel.date
                        )
                    }
                }
            }
        }
    }

    private var remindersCard: some View {
        CreationSectionCard(title: "Reminders", icon: "bell") {
            VStack(spacing: AppTheme.Space.sm) {
                Menu {
                    ForEach(ReminderInterval.allCases, id: \.self) { interval in
                        Button(interval.displayName) {
                            viewModel.addReminder(interval)
                        }
                        .disabled(viewModel.reminders.contains { $0.interval == interval })
                    }
                } label: {
                    HStack {
                        Label("Add Reminder", systemImage: "plus.circle")
                            .font(AppTheme.TextStyle.bodyBold)
                            .foregroundStyle(AppTheme.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.Space.md)
                    .padding(.vertical, AppTheme.Space.sm)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                }

                if viewModel.reminders.isEmpty {
                    Text("No reminders set")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                } else {
                    ForEach(viewModel.reminders) { reminder in
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(AppTheme.warning)
                            Text(reminder.interval.displayName)
                                .font(AppTheme.TextStyle.secondary)
                            Spacer()
                            Button {
                                viewModel.removeReminder(reminder)
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
                }
            }
        }
    }

    private var categoryPriorityCard: some View {
        CreationSectionCard(title: "Category & Priority", icon: "tag") {
            VStack(spacing: AppTheme.Space.sm) {
                pickerRow(title: "Category") {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(EventCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if viewModel.category == .custom {
                    VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                        Text("Custom Category Name")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        CustomCategoryPickerRows(
                            selectedName: $viewModel.customCategoryName,
                            savedCategories: CustomCategoryStore.shared.eventCategories,
                            onDelete: { CustomCategoryStore.shared.removeEventCategory($0) }
                        )
                    }
                    .padding(AppTheme.Space.md)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                }

                CreationInlineError(text: viewModel.customCategoryError)

                pickerRow(title: "Priority") {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(EventPriority.allCases, id: \.self) { priority in
                            Label(priority.displayName, systemImage: priority.icon)
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var linksCostCard: some View {
        CreationSectionCard(title: "Links & Cost", icon: "link") {
            VStack(spacing: AppTheme.Space.sm) {
                TextField("Website URL (optional)", text: $viewModel.urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .url)
                    .designField(isFocused: focusedField == .url)

                HStack {
                    Text(viewModel.currency)
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    TextField("Cost (optional)", text: $viewModel.costString)
                        .focused($focusedField, equals: .cost)
                        .keyboardType(.decimalPad)
                        .font(AppTheme.TextStyle.body)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, AppTheme.Space.md)
                .padding(.vertical, AppTheme.Space.sm)
                .background(AppTheme.surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                CreationInlineError(text: viewModel.costError)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppTheme.Space.sm) {
                        TextField("Link name", text: $newLinkName)
                            .focused($focusedField, equals: .linkName)
                            .designField(isFocused: focusedField == .linkName)
                        TextField("https://...", text: $newLinkURL)
                            .focused($focusedField, equals: .linkURL)
                            .textInputAutocapitalization(.never)
                            .designField(isFocused: focusedField == .linkURL)
                    }

                    VStack(spacing: AppTheme.Space.sm) {
                        TextField("Link name", text: $newLinkName)
                            .focused($focusedField, equals: .linkName)
                            .designField(isFocused: focusedField == .linkName)
                        TextField("https://...", text: $newLinkURL)
                            .focused($focusedField, equals: .linkURL)
                            .textInputAutocapitalization(.never)
                            .designField(isFocused: focusedField == .linkURL)
                    }
                }

                Button {
                    let initialCount = viewModel.attachments.count
                    viewModel.addLinkAttachment(name: newLinkName, urlString: newLinkURL)
                    if viewModel.attachments.count > initialCount {
                        newLinkName = ""
                        newLinkURL = ""
                    }
                } label: {
                    Label("Add Link", systemImage: "link.badge.plus")
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.Space.md)
                        .padding(.vertical, AppTheme.Space.sm)
                        .background(AppTheme.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(newLinkName.trimmingCharacters(in: .whitespaces).isEmpty || newLinkURL.trimmingCharacters(in: .whitespaces).isEmpty)

                let linkAttachments = viewModel.attachments.filter { $0.type == .link }
                ForEach(linkAttachments) { attachment in
                    HStack {
                        Image(systemName: attachment.type.icon)
                            .foregroundStyle(AppTheme.tertiary)
                        Text(attachment.name)
                            .font(AppTheme.TextStyle.secondary)
                        Spacer()
                        Button {
                            viewModel.removeAttachment(attachment)
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
            }
        }
    }

    private func pickerRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
            Spacer()
            content()
                .tint(AppTheme.tertiary)
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
    }

    private var photosCard: some View {
        CreationSectionCard(title: "Photos", icon: "photo") {
            PhotosPickerSection(photoAttachments: $viewModel.photoAttachments)
        }
    }

    private var notesCard: some View {
        CreationSectionCard(title: "Notes", icon: "note.text") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.notes)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))

                if viewModel.notes.isEmpty {
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

    private var selectedDaysText: String {
        if viewModel.selectedDaysOfWeek.isEmpty { return "None" }
        if viewModel.selectedDaysOfWeek.count == 7 { return "Every day" }
        return viewModel.selectedDaysOfWeek
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.shortName }
            .joined(separator: ", ")
    }
}

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
                                .foregroundStyle(AppTheme.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Days")
        .navigationBarTitleDisplayMode(.inline)
    }
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
