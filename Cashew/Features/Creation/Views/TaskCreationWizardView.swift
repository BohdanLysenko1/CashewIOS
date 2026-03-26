import SwiftUI

struct TaskCreationWizardView: View {

    @State private var viewModel: TaskCreationWizardViewModel
    private let tripService: TripServiceProtocol
    private let eventService: EventServiceProtocol
    let onCreated: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var showError = false
    @State private var goingForward = true
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title, subtask, notes
    }

    init(
        service: DayPlannerServiceProtocol,
        tripService: TripServiceProtocol,
        eventService: EventServiceProtocol,
        defaultDate: Date,
        onCreated: @escaping (UUID) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.tripService = tripService
        self.eventService = eventService
        _viewModel = State(initialValue: TaskCreationWizardViewModel(
            service: service,
            tripService: tripService,
            eventService: eventService,
            defaultDate: defaultDate
        ))
        self.onCreated = onCreated
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .background(CreationScreenBackground(gradient: AppTheme.dayPlannerGradient))
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
        .onChange(of: viewModel.savedTaskId) { _, id in
            if let id {
                onCreated(id)
                onDismiss()
            }
        }
        .task {
            await viewModel.loadLinkedDataIfNeeded()
        }
    }

    private var header: some View {
        CreationWizardHeader(
            title: viewModel.stepTitle,
            currentStep: viewModel.currentStep,
            totalSteps: TaskCreationWizardViewModel.totalSteps,
            gradient: AppTheme.dayPlannerGradient,
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
                case 1: scheduleStep
                case 2: categoryAndLinksStep
                case 3: subtasksStep
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
            fieldCard(label: "Task Name") {
                TextField("e.g. Book hotel transfer", text: $viewModel.title)
                    .font(AppTheme.TextStyle.body)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
            }

            infoCard {
                HStack {
                    Text("Date")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurface)
                    Spacer()
                    DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(AppTheme.primary)
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = .title
            }
        }
    }

    private var scheduleStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            infoCard {
                VStack(spacing: 0) {
                    toggleRow(title: "Set Time", isOn: $viewModel.hasTime)
                    if viewModel.hasTime {
                        Divider().padding(.leading, AppTheme.Space.lg)
                        timeRow(title: "Start", selection: $viewModel.startTime)

                        Divider().padding(.leading, AppTheme.Space.lg)
                        toggleRow(title: "Set End Time", isOn: $viewModel.hasEndTime)

                        if viewModel.hasEndTime {
                            Divider().padding(.leading, AppTheme.Space.lg)
                            timeRow(title: "End", selection: $viewModel.endTime, minDate: viewModel.startTime)
                        }
                    }
                }
            }

            if viewModel.hasTime && viewModel.hasEndTime && viewModel.endTime < viewModel.startTime {
                CreationInlineError(text: "End time must be after start time")
                    .padding(.horizontal, AppTheme.Space.xs)
            } else {
                Text("Tasks without a specific time will appear in your to-do list.")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(.horizontal, AppTheme.Space.xs)
            }
        }
    }

    private var categoryAndLinksStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Space.sm) {
                    ForEach(TaskCategory.allCases, id: \.self) { cat in
                        let isSelected = viewModel.category == cat
                        Button {
                            HapticManager.impact(.light)
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
                                    ? AnyShapeStyle(AppTheme.dayPlannerGradient)
                                    : AnyShapeStyle(AppTheme.surfaceContainerLow)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
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
                            savedCategories: CustomCategoryStore.shared.taskCategories,
                            onDelete: { CustomCategoryStore.shared.removeTaskCategory($0) }
                        )
                    }
                    .padding(AppTheme.Space.lg)
                }
            }

            infoCard {
                VStack(spacing: 0) {
                    pickerRow(title: "Trip", selected: selectedTripTitle) {
                        Button("None") {
                            viewModel.selectedTripId = nil
                        }
                        ForEach(viewModelTripOptions) { trip in
                            Button(trip.name) {
                                viewModel.selectedTripId = trip.id
                            }
                        }
                    }

                    Divider().padding(.leading, AppTheme.Space.lg)

                    pickerRow(title: "Event", selected: selectedEventTitle) {
                        Button("None") {
                            viewModel.selectedEventId = nil
                        }
                        ForEach(viewModelEventOptions) { event in
                            Button(event.title) {
                                viewModel.selectedEventId = event.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var subtasksStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            infoCard {
                HStack(spacing: AppTheme.Space.sm) {
                    TextField("Add subtask...", text: $viewModel.newSubtaskTitle)
                        .focused($focusedField, equals: .subtask)
                        .submitLabel(.done)
                        .onSubmit {
                            guard !viewModel.newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            HapticManager.impact(.medium)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                viewModel.addSubtask()
                            }
                        }
                        .font(AppTheme.TextStyle.body)

                    Button {
                        HapticManager.impact(.medium)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            viewModel.addSubtask()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                viewModel.newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AppTheme.onSurfaceVariant.opacity(0.35)
                                    : AppTheme.primary
                            )
                    }
                    .disabled(viewModel.newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }

            if !viewModel.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                    Text("Added (\(viewModel.subtasks.count))")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    ForEach(viewModel.subtasks) { subtask in
                        HStack(spacing: 10) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(subtask.isCompleted ? .green : AppTheme.onSurfaceVariant)
                                .frame(width: 20)
                            Text(subtask.title)
                                .font(AppTheme.TextStyle.body)
                                .foregroundStyle(AppTheme.onSurface)
                            Spacer()
                            Button {
                                HapticManager.impact(.light)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.removeSubtask(subtask)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.7))
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .padding(.leading, AppTheme.Space.md)
                        .padding(.trailing, AppTheme.Space.xs)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 2)
                    }
                }
            }
        }
    }

    private var notesStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            fieldCard(label: "Notes (optional)") {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.notes)
                        .focused($focusedField, equals: .notes)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .font(AppTheme.TextStyle.body)

                    if viewModel.notes.isEmpty {
                        Text("Any context to make this easier to complete...")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        let isLastStep = viewModel.currentStep == TaskCreationWizardViewModel.totalSteps - 1
        return CreationWizardNavigationBar(
            isFirstStep: viewModel.currentStep == 0,
            isLastStep: isLastStep,
            canContinue: viewModel.isCurrentStepValid,
            isLoading: viewModel.isSaving,
            gradient: AppTheme.dayPlannerGradient,
            finalStepTitle: "Create Task",
            onBack: {
                HapticManager.impact(.medium)
                goingForward = false
                withAnimation(.easeInOut(duration: 0.3)) { viewModel.goBack() }
            },
            onContinue: {
                HapticManager.impact(isLastStep ? .heavy : .medium)
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

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
                .font(AppTheme.TextStyle.body)
                .tint(AppTheme.primary)
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, AppTheme.Space.md)
    }

    private func timeRow(title: String, selection: Binding<Date>, minDate: Date? = nil) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
                .frame(minWidth: 48, idealWidth: 56, maxWidth: 80, alignment: .leading)
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
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, AppTheme.Space.md)
    }

    private func pickerRow<MenuContent: View>(title: String, selected: String, @ViewBuilder menu: () -> MenuContent) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
            Spacer()
            Menu {
                menu()
            } label: {
                HStack(spacing: 6) {
                    Text(selected)
                        .font(AppTheme.TextStyle.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, AppTheme.Space.md)
    }

    private var selectedTripTitle: String {
        guard let id = viewModel.selectedTripId else { return "None" }
        return viewModelTripOptions.first(where: { $0.id == id })?.name ?? "None"
    }

    private var selectedEventTitle: String {
        guard let id = viewModel.selectedEventId else { return "None" }
        return viewModelEventOptions.first(where: { $0.id == id })?.title ?? "None"
    }

    private var viewModelTripOptions: [Trip] {
        tripService.trips
    }

    private var viewModelEventOptions: [Event] {
        eventService.events
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}
