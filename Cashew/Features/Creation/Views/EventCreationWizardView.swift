import SwiftUI

struct EventCreationWizardView: View {

    @State private var viewModel: EventCreationWizardViewModel
    let onCreated: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var showError = false
    @State private var goingForward = true
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title, cost, notes
    }

    init(eventService: EventServiceProtocol, onCreated: @escaping (UUID) -> Void, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: EventCreationWizardViewModel(eventService: eventService))
        self.onCreated = onCreated
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .background(AppTheme.background)
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

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .padding(10)
                        .background(AppTheme.surfaceContainerLow)
                        .clipShape(Circle())
                }
                Spacer()
            }

            VStack(spacing: 2) {
                Text(viewModel.stepTitle)
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)
                Text("Step \(viewModel.currentStep + 1) of \(EventCreationWizardViewModel.totalSteps)")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
            .id(viewModel.currentStep)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, AppTheme.Space.md)
        .padding(.bottom, AppTheme.Space.sm)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.surfaceContainerLow)
                    .frame(height: 4)
                Capsule()
                    .fill(AppTheme.eventGradient)
                    .frame(
                        width: geo.size.width * CGFloat(viewModel.currentStep + 1) / CGFloat(EventCreationWizardViewModel.totalSteps),
                        height: 4
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.currentStep)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.bottom, AppTheme.Space.lg)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.xl) {
                Text(viewModel.stepSubtitle)
                    .font(AppTheme.TextStyle.secondary)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                switch viewModel.currentStep {
                case 0: basicsStep
                case 1: dateTimeStep
                case 2: detailsStep
                case 3: notesStep
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

    // MARK: - Step 0: Basics

    private var basicsStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            fieldCard(label: "Event Title") {
                TextField("e.g. Team Meeting", text: $viewModel.title)
                    .font(AppTheme.TextStyle.body)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
            }

            // Location NOT wrapped in fieldCard so autocomplete dropdown is not clipped
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
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                focusedField = .title
            }
        }
    }

    // MARK: - Step 1: Date & Time

    private var dateTimeStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            infoCard {
                VStack(spacing: 0) {
                    dateRow(label: "Date", date: $viewModel.date, isAllDay: viewModel.isAllDay)

                    Divider().padding(.leading, AppTheme.Space.lg)

                    HStack {
                        Toggle("All Day", isOn: $viewModel.isAllDay)
                            .font(AppTheme.TextStyle.body)
                            .tint(AppTheme.tertiary)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)

                    Divider().padding(.leading, AppTheme.Space.lg)

                    HStack {
                        Toggle("Set End Time", isOn: $viewModel.hasEndDate)
                            .font(AppTheme.TextStyle.body)
                            .tint(AppTheme.tertiary)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)

                    if viewModel.hasEndDate {
                        Divider().padding(.leading, AppTheme.Space.lg)
                        dateRow(label: "End", date: $viewModel.endDate, isAllDay: viewModel.isAllDay, minDate: viewModel.date)
                    }
                }
            }

            if viewModel.hasEndDate && viewModel.endDate < viewModel.date {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                    Text("End must be after start")
                        .font(AppTheme.TextStyle.caption)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, AppTheme.Space.xs)
            }
        }
    }

    private func dateRow(label: String, date: Binding<Date>, isAllDay: Bool, minDate: Date? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
                .frame(width: 48, alignment: .leading)
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

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            // Category grid
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Space.sm) {
                    ForEach(EventCategory.allCases.filter { $0 != .custom }, id: \.self) { cat in
                        let isSelected = viewModel.category == cat
                        Button {
                            haptic()
                            viewModel.category = cat
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 18))
                                Text(cat.displayName)
                                    .font(AppTheme.TextStyle.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
                            .background(isSelected ? AppTheme.eventGradient : LinearGradient(colors: [AppTheme.surfaceContainerLow], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Priority
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

            // Cost (currency + amount in a single card)
            infoCard {
                VStack(spacing: 0) {
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
                            .frame(width: 120)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)
                }
            }
        }
    }

    // MARK: - Step 3: Notes & Photos

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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: AppTheme.Space.md) {
            // Always laid out — invisible on step 0 so Next button width stays stable
            Button {
                haptic(.medium)
                goingForward = false
                withAnimation(.easeInOut(duration: 0.3)) { viewModel.goBack() }
            } label: {
                Text("Back")
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)
                    .frame(width: 88)
                    .padding(.vertical, 16)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
            }
            .buttonStyle(.plain)
            .opacity(viewModel.currentStep > 0 ? 1 : 0)
            .disabled(viewModel.currentStep == 0)

            let isLastStep = viewModel.currentStep == EventCreationWizardViewModel.totalSteps - 1
            Button {
                haptic(isLastStep ? .heavy : .medium)
                goingForward = true
                if isLastStep {
                    Task { await viewModel.save() }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.goNext() }
                }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(isLastStep ? "Create Event" : "Next")
                            .font(AppTheme.TextStyle.bodyBold)
                            .foregroundStyle(.white)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.18), value: isLastStep)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(
                viewModel.isCurrentStepValid
                    ? AnyShapeStyle(AppTheme.eventGradient)
                    : AnyShapeStyle(AppTheme.onSurfaceVariant.opacity(0.25))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
            .disabled(!viewModel.isCurrentStepValid || viewModel.isSaving)
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isCurrentStepValid)
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, AppTheme.Space.md)
        .padding(.bottom, AppTheme.Space.lg)
        .background {
            AppTheme.background
                .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: -4)
                .ignoresSafeArea()
        }
    }

    // MARK: - Reusable Containers

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

    // MARK: - Transition

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Helpers

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
