import SwiftUI

struct EventCreationWizardView: View {

    @State private var viewModel: EventCreationWizardViewModel
    let onCreated: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var showError = false
    @State private var goingForward = true
    @State private var newLinkName = ""
    @State private var newLinkURL = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title, cost, notes, linkName, linkURL
    }

    init(eventService: EventServiceProtocol, onCreated: @escaping (UUID) -> Void, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: EventCreationWizardViewModel(eventService: eventService))
        self.onCreated = onCreated
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .background(CreationScreenBackground(gradient: AppTheme.eventGradient))
        .onChange(of: viewModel.error) { _, newError in showError = newError != nil }
        .alert("Error", isPresented: $showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.error { Text(error) }
        }
        .onChange(of: viewModel.savedEventId) { _, id in
            if let id {
                onCreated(id)
                onDismiss()
            }
        }
    }

    private var header: some View {
        CreationWizardHeader(
            title: viewModel.stepTitle,
            currentStep: viewModel.currentStep,
            totalSteps: EventCreationWizardViewModel.totalSteps,
            gradient: AppTheme.eventGradient,
            onClose: onDismiss
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.xl) {
                Text(viewModel.stepSubtitle)
                    .font(AppTheme.TextStyle.secondary)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                switch viewModel.currentStep {
                case 0: basicsStep
                case 1: dateTimeStep
                case 2: planningStep
                case 3: linksAndCostStep
                case 4: notesStep
                default: EmptyView()
                }
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.bottom, AppTheme.Space.xxxl)
        }
        .id(viewModel.currentStep)
        .transition(stepTransition)
        .scrollDismissesKeyboard(.interactively)
    }

    private var basicsStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            fieldCard(label: "Event Title") {
                TextField("e.g. Team Meeting", text: $viewModel.title)
                    .font(AppTheme.TextStyle.body)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Location (optional)")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                LocationSearchField(
                    text: $viewModel.location,
                    latitude: $viewModel.locationLatitude,
                    longitude: $viewModel.locationLongitude,
                    label: "Location",
                    placeholder: "Search for a place..."
                )
                .padding(AppTheme.Space.md)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
            }

            fieldCard(label: "Address (optional)") {
                TextField("Street address", text: $viewModel.address)
                    .font(AppTheme.TextStyle.body)
                    .textContentType(.fullStreetAddress)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                focusedField = .title
            }
        }
    }

    private var dateTimeStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            infoCard {
                VStack(spacing: 0) {
                    dateRow(label: "Date", date: $viewModel.date, isAllDay: viewModel.isAllDay)

                    Divider().padding(.leading, AppTheme.Space.lg)

                    toggleRow("All Day", isOn: $viewModel.isAllDay)

                    Divider().padding(.leading, AppTheme.Space.lg)

                    toggleRow("Set End Time", isOn: $viewModel.hasEndDate)

                    if viewModel.hasEndDate {
                        Divider().padding(.leading, AppTheme.Space.lg)
                        dateRow(label: "End", date: $viewModel.endDate, isAllDay: viewModel.isAllDay, minDate: viewModel.date)
                    }
                }
            }

            if viewModel.hasEndDate && viewModel.endDate < viewModel.date {
                CreationInlineError(text: "End must be after start")
                    .padding(.horizontal, AppTheme.Space.xs)
            }
        }
    }

    private var planningStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            categorySection
            prioritySection
            recurrenceSection
            remindersSection
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurfaceVariant)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Space.sm) {
                ForEach(EventCategory.allCases, id: \.self) { cat in
                    let isSelected = viewModel.category == cat
                    Button {
                        haptic()
                        viewModel.category = cat
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(cat.displayName)
                                .font(AppTheme.TextStyle.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
                        .background(
                            isSelected
                                ? AnyShapeStyle(AppTheme.eventGradient)
                                : AnyShapeStyle(AppTheme.surfaceContainerLow)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.category == .custom {
                infoCard {
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
                    .padding(AppTheme.Space.lg)
                }
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Priority")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurfaceVariant)

            HStack(spacing: AppTheme.Space.sm) {
                ForEach([EventPriority.low, .medium, .high], id: \.self) { p in
                    let isSelected = viewModel.priority == p
                    Button {
                        haptic()
                        viewModel.priority = p
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: p.icon)
                                .font(.system(size: 13))
                            Text(p.displayName)
                                .font(AppTheme.TextStyle.captionBold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
                        .background(isSelected ? priorityGradient(p) : LinearGradient(colors: [AppTheme.surfaceContainerLow], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recurrenceSection: some View {
        infoCard {
            VStack(spacing: 0) {
                toggleRow("Repeat", isOn: $viewModel.isRecurring)

                if viewModel.isRecurring {
                    Divider().padding(.leading, AppTheme.Space.lg)
                    HStack {
                        Text("Frequency")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        Picker("Frequency", selection: $viewModel.recurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.tertiary)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)

                    Divider().padding(.leading, AppTheme.Space.lg)
                    Stepper(
                        "Every \(viewModel.recurrenceInterval) \(viewModel.recurrenceFrequency.pluralName)",
                        value: $viewModel.recurrenceInterval,
                        in: 1...30
                    )
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)

                    if viewModel.recurrenceFrequency == .weekly {
                        Divider().padding(.leading, AppTheme.Space.lg)
                        NavigationLink {
                            DayOfWeekPicker(selectedDays: $viewModel.selectedDaysOfWeek)
                        } label: {
                            HStack {
                                Text("Days")
                                    .font(AppTheme.TextStyle.body)
                                Spacer()
                                Text(selectedDaysText)
                                    .font(AppTheme.TextStyle.secondary)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                            }
                            .padding(.horizontal, AppTheme.Space.lg)
                            .padding(.vertical, AppTheme.Space.md)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().padding(.leading, AppTheme.Space.lg)
                    toggleRow("End Date", isOn: $viewModel.hasRecurrenceEndDate)

                    if viewModel.hasRecurrenceEndDate {
                        Divider().padding(.leading, AppTheme.Space.lg)
                        HStack {
                            Text("Ends On")
                                .font(AppTheme.TextStyle.body)
                                .foregroundStyle(AppTheme.onSurface)
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.recurrenceEndDate ?? viewModel.date.addingTimeInterval(86400 * 30) },
                                    set: { viewModel.recurrenceEndDate = $0 }
                                ),
                                in: viewModel.date...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .tint(AppTheme.tertiary)
                        }
                        .padding(.horizontal, AppTheme.Space.lg)
                        .padding(.vertical, AppTheme.Space.md)
                    }
                }
            }
        }
    }

    private var remindersSection: some View {
        infoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Reminders")
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                    Spacer()
                    Menu {
                        ForEach(ReminderInterval.allCases, id: \.self) { interval in
                            Button(interval.displayName) {
                                viewModel.addReminder(interval)
                            }
                            .disabled(viewModel.reminders.contains { $0.interval == interval })
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.tertiary)
                    }
                }

                if viewModel.reminders.isEmpty {
                    Text("No reminders added")
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                } else {
                    ForEach(viewModel.reminders) { reminder in
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.orange)
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
                    }
                }
            }
            .padding(AppTheme.Space.lg)
        }
    }

    private var linksAndCostStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            infoCard {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event URL")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                        TextField("https://", text: $viewModel.urlString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .font(AppTheme.TextStyle.body)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)

                    Divider().padding(.leading, AppTheme.Space.lg)

                    HStack {
                        Text("Currency")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        Picker("Currency", selection: $viewModel.currency) {
                            ForEach(EventCreationWizardViewModel.currencies, id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.secondary)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)

                    Divider().padding(.leading, AppTheme.Space.lg)

                    HStack {
                        Text("Cost (optional)")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        TextField("0.00", text: $viewModel.costString)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .cost)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.TextStyle.body)
                            .frame(minWidth: 70, maxWidth: 140)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)
                }
            }

            infoCard {
                VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                    Text("Link Attachments")
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppTheme.Space.sm) {
                            TextField("Link name", text: $newLinkName)
                                .focused($focusedField, equals: .linkName)
                                .font(AppTheme.TextStyle.secondary)
                            TextField("https://...", text: $newLinkURL)
                                .focused($focusedField, equals: .linkURL)
                                .textInputAutocapitalization(.never)
                                .font(AppTheme.TextStyle.secondary)
                        }

                        VStack(spacing: AppTheme.Space.sm) {
                            TextField("Link name", text: $newLinkName)
                                .focused($focusedField, equals: .linkName)
                                .font(AppTheme.TextStyle.secondary)
                            TextField("https://...", text: $newLinkURL)
                                .focused($focusedField, equals: .linkURL)
                                .textInputAutocapitalization(.never)
                                .font(AppTheme.TextStyle.secondary)
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
                        Label("Add Link Attachment", systemImage: "link.badge.plus")
                            .font(AppTheme.TextStyle.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newLinkName.trimmingCharacters(in: .whitespaces).isEmpty || newLinkURL.trimmingCharacters(in: .whitespaces).isEmpty)

                    let linkAttachments = viewModel.attachments.filter { $0.type == .link }
                    if !linkAttachments.isEmpty {
                        ForEach(linkAttachments) { attachment in
                            HStack {
                                Image(systemName: "link")
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
                        }
                    }
                }
                .padding(AppTheme.Space.lg)
            }
        }
    }

    private var notesStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            fieldCard(label: "Notes (optional)") {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.notes)
                        .focused($focusedField, equals: .notes)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                        .font(AppTheme.TextStyle.body)
                    if viewModel.notes.isEmpty {
                        Text("Any details about this event...")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            }

            PhotosPickerSection(photoAttachments: $viewModel.photoAttachments)
        }
    }

    private var bottomBar: some View {
        let isLastStep = viewModel.currentStep == EventCreationWizardViewModel.totalSteps - 1
        return CreationWizardNavigationBar(
            isFirstStep: viewModel.currentStep == 0,
            isLastStep: isLastStep,
            canContinue: viewModel.isCurrentStepValid,
            isLoading: viewModel.isSaving,
            gradient: AppTheme.eventGradient,
            finalStepTitle: "Create Event",
            onBack: {
                haptic(.medium)
                goingForward = false
                withAnimation(.easeInOut(duration: 0.3)) { viewModel.goBack() }
            },
            onContinue: {
                haptic(isLastStep ? .heavy : .medium)
                goingForward = true
                if isLastStep {
                    Task { await viewModel.save() }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.goNext() }
                }
            }
        )
    }

    private func fieldCard<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurfaceVariant)
            content()
                .padding(AppTheme.Space.md)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
                .font(AppTheme.TextStyle.body)
                .tint(AppTheme.tertiary)
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, AppTheme.Space.md)
    }

    private func dateRow(label: String, date: Binding<Date>, isAllDay: Bool, minDate: Date? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
                .frame(minWidth: 42, idealWidth: 48, maxWidth: 80, alignment: .leading)
            Spacer()
            let components: DatePickerComponents = isAllDay ? .date : [.date, .hourAndMinute]
            if let minDate {
                DatePicker("", selection: date, in: minDate..., displayedComponents: components)
                    .labelsHidden()
                    .tint(AppTheme.tertiary)
            } else {
                DatePicker("", selection: date, displayedComponents: components)
                    .labelsHidden()
                    .tint(AppTheme.tertiary)
            }
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, AppTheme.Space.md)
    }

    private var selectedDaysText: String {
        if viewModel.selectedDaysOfWeek.isEmpty { return "None" }
        if viewModel.selectedDaysOfWeek.count == 7 { return "Every day" }
        return viewModel.selectedDaysOfWeek
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.shortName }
            .joined(separator: ", ")
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func priorityGradient(_ priority: EventPriority) -> LinearGradient {
        switch priority {
        case .low:    return LinearGradient(colors: [.green.opacity(0.7), .green], startPoint: .leading, endPoint: .trailing)
        case .medium: return LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .leading, endPoint: .trailing)
        case .high:   return LinearGradient(colors: [.red.opacity(0.7), .red], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
