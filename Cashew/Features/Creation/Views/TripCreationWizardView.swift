import SwiftUI

struct TripCreationWizardView: View {

    @State private var viewModel: TripCreationWizardViewModel
    let onCreated: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var showError = false
    @State private var goingForward = true
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, budget, packingItem, checklistItem, notes
    }

    init(tripService: TripServiceProtocol, onCreated: @escaping (UUID) -> Void, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: TripCreationWizardViewModel(tripService: tripService))
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
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .onChange(of: viewModel.error) { _, newError in showError = newError != nil }
        .alert("Error", isPresented: $showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.error { Text(error) }
        }
        .onChange(of: viewModel.savedTripId) { _, id in
            if let id {
                onCreated(id)
                onDismiss()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        CreationWizardHeader(
            title: viewModel.stepTitle,
            currentStep: viewModel.currentStep,
            totalSteps: TripCreationWizardViewModel.totalSteps,
            gradient: AppTheme.tripGradient,
            onClose: onDismiss
        )
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
                case 1: datesStep
                case 2: budgetStep
                case 3: packingStep
                case 4: checklistStep
                case 5: notesStep
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
            fieldCard(label: "Trip Name") {
                TextField("e.g. Summer in Italy", text: $viewModel.name)
                    .font(AppTheme.TextStyle.body)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
            }

            // Location field NOT clipped so its autocomplete dropdown is visible
            VStack(alignment: .leading, spacing: 6) {
                Text("Destination")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                LocationSearchField(
                    text: $viewModel.destination,
                    latitude: $viewModel.destinationLatitude,
                    longitude: $viewModel.destinationLongitude,
                    label: "Destination",
                    placeholder: "Search a place..."
                )
                .padding(AppTheme.Space.md)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                focusedField = .name
            }
        }
    }

    // MARK: - Step 1: Dates

    private var datesStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            infoCard {
                VStack(spacing: 0) {
                    dateRow(label: "Start", selection: $viewModel.startDate)
                    Divider().padding(.leading, AppTheme.Space.lg)
                    dateRow(label: "End", selection: Binding(
                        get: { viewModel.endDate },
                        set: { viewModel.endDate = $0 }
                    ), minDate: viewModel.startDate)
                }
            }

            if viewModel.endDate < viewModel.startDate {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                    Text("End date must be after start date")
                        .font(AppTheme.TextStyle.caption)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, AppTheme.Space.xs)
            }
        }
    }

    private func dateRow(label: String, selection: Binding<Date>, minDate: Date? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
                .frame(width: 48, alignment: .leading)
            Spacer()
            if let minDate {
                DatePicker("", selection: selection, in: minDate..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppTheme.secondary)
            } else {
                DatePicker("", selection: selection, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppTheme.secondary)
            }
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, AppTheme.Space.md)
    }

    // MARK: - Step 2: Budget

    private var budgetStep: some View {
        VStack(spacing: AppTheme.Space.md) {
            infoCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("Currency")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        Picker("Currency", selection: $viewModel.currency) {
                            ForEach(TripCreationWizardViewModel.currencies, id: \.self) { c in
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
                        Text("Budget")
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.onSurface)
                        Spacer()
                        TextField("0.00", text: $viewModel.budgetString)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .budget)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.TextStyle.body)
                            .frame(width: 120)
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                    .padding(.vertical, AppTheme.Space.md)
                }
            }

            Text("Optional — you can always set this later in the trip's budget tab.")
                .font(AppTheme.TextStyle.caption)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding(.horizontal, AppTheme.Space.xs)
        }
    }

    // MARK: - Step 3: Packing

    private var packingStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.lg) {
            // Add new item row
            infoCard {
                HStack(spacing: AppTheme.Space.sm) {
                    TextField("Add item...", text: $viewModel.newPackingItemName)
                        .focused($focusedField, equals: .packingItem)
                        .submitLabel(.done)
                        .onSubmit {
                            if !viewModel.newPackingItemName.trimmingCharacters(in: .whitespaces).isEmpty {
                                haptic(.medium)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { viewModel.addPackingItem() }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedField = .packingItem }
                            }
                        }
                        .font(AppTheme.TextStyle.body)

                    Menu {
                        ForEach(PackingCategory.allCases, id: \.self) { cat in
                            Button {
                                viewModel.newPackingCategory = cat
                            } label: {
                                Label(cat.displayName, systemImage: cat.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: viewModel.newPackingCategory.icon)
                                .font(.system(size: 14))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(AppTheme.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        haptic(.medium)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { viewModel.addPackingItem() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedField = .packingItem }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(viewModel.newPackingItemName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AppTheme.onSurfaceVariant.opacity(0.3)
                                : AppTheme.secondary)
                            .font(.system(size: 24))
                    }
                    .disabled(viewModel.newPackingItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }

            // Suggestions
            VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                Text("Quick add")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Space.sm) {
                    ForEach(TripCreationWizardViewModel.packingSuggestions, id: \.name) { suggestion in
                        let isAdded = viewModel.isSuggestedPackingItemAdded(suggestion.name)
                        Button {
                            haptic()
                            viewModel.toggleSuggestedPackingItem(name: suggestion.name, category: suggestion.category)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isAdded ? "checkmark.circle.fill" : suggestion.category.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isAdded ? .white : AppTheme.secondary)
                                Text(suggestion.name)
                                    .font(AppTheme.TextStyle.captionBold)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .foregroundStyle(isAdded ? .white : AppTheme.onSurface)
                            .background(isAdded ? AppTheme.tripGradient : LinearGradient(colors: [AppTheme.surfaceContainerLow], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .animation(.easeInOut(duration: 0.15), value: isAdded)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Added items list
            if !viewModel.packingItems.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                    Text("Added (\(viewModel.packingItems.count))")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    ForEach(viewModel.packingItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.category.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondary)
                                .frame(width: 20)
                            Text(item.name)
                                .font(AppTheme.TextStyle.body)
                                .foregroundStyle(AppTheme.onSurface)
                            Spacer()
                            Text(item.category.displayName)
                                .font(AppTheme.TextStyle.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Button {
                                haptic(.light)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.packingItems.removeAll { $0.id == item.id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.6))
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
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Checklist

    private var checklistStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.lg) {
            // Add new item row
            infoCard {
                HStack(spacing: AppTheme.Space.sm) {
                    TextField("Add task...", text: $viewModel.newChecklistTitle)
                        .focused($focusedField, equals: .checklistItem)
                        .submitLabel(.done)
                        .onSubmit {
                            if !viewModel.newChecklistTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                haptic(.medium)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { viewModel.addChecklistItem() }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedField = .checklistItem }
                            }
                        }
                        .font(AppTheme.TextStyle.body)

                    Menu {
                        ForEach(ChecklistPriority.allCases, id: \.self) { p in
                            Button {
                                viewModel.newChecklistPriority = p
                            } label: {
                                Label(p.displayName, systemImage: p.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: viewModel.newChecklistPriority.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(priorityColor(viewModel.newChecklistPriority))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(AppTheme.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        haptic(.medium)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { viewModel.addChecklistItem() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedField = .checklistItem }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(viewModel.newChecklistTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AppTheme.onSurfaceVariant.opacity(0.3)
                                : AppTheme.secondary)
                            .font(.system(size: 24))
                    }
                    .disabled(viewModel.newChecklistTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }

            // Suggestions
            VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                Text("Quick add")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                VStack(spacing: AppTheme.Space.xs) {
                    ForEach(TripCreationWizardViewModel.checklistSuggestions, id: \.title) { suggestion in
                        let isAdded = viewModel.isSuggestedChecklistItemAdded(suggestion.title)
                        Button {
                            haptic()
                            viewModel.toggleSuggestedChecklistItem(title: suggestion.title, priority: suggestion.priority)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: suggestion.priority.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isAdded ? .white : priorityColor(suggestion.priority))
                                    .frame(width: 18)
                                Text(suggestion.title)
                                    .font(AppTheme.TextStyle.body)
                                Spacer()
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isAdded ? .white : AppTheme.onSurfaceVariant)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, 10)
                            .foregroundStyle(isAdded ? .white : AppTheme.onSurface)
                            .background(isAdded ? AppTheme.tripGradient : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
                            .animation(.easeInOut(duration: 0.15), value: isAdded)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Added items list
            if !viewModel.checklistItems.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                    Text("Added (\(viewModel.checklistItems.count))")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    ForEach(viewModel.checklistItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.priority.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(priorityColor(item.priority))
                                .frame(width: 20)
                            Text(item.title)
                                .font(AppTheme.TextStyle.body)
                                .foregroundStyle(AppTheme.onSurface)
                            Spacer()
                            Text(item.priority.displayName)
                                .font(AppTheme.TextStyle.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Button {
                                haptic(.light)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.checklistItems.removeAll { $0.id == item.id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.6))
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
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Notes & Photos

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
                        Text("Any other details about your trip...")
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
        let isLastStep = viewModel.currentStep == TripCreationWizardViewModel.totalSteps - 1
        return CreationWizardNavigationBar(
            isFirstStep: viewModel.currentStep == 0,
            isLastStep: isLastStep,
            canContinue: viewModel.isCurrentStepValid,
            isLoading: viewModel.isSaving,
            gradient: AppTheme.tripGradient,
            finalStepTitle: "Create Trip",
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

    private func priorityColor(_ priority: ChecklistPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
