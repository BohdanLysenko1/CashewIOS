import SwiftUI

struct RoutineFormView: View {

    @Environment(\.dismiss) private var dismiss

    let service: DayPlannerServiceProtocol
    let routine: DailyRoutine?

    @State private var title: String = ""
    @State private var hasTime = false
    @State private var startTime: Date = Date()
    @State private var hasEndTime = false
    @State private var endTime: Date = Date()
    @State private var category: TaskCategory = .personal
    @State private var repeatPattern: RepeatPattern = .daily
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var notes: String = ""

    @State private var isSaving = false
    @State private var error: String?
    @State private var showError = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, notes }

    private var isEditing: Bool { routine != nil }

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let hasValidDays = repeatPattern != .custom || !selectedDays.isEmpty
        return hasTitle && hasValidDays
    }

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: isEditing ? "Edit Routine" : "New Routine",
                subtitle: isEditing ? "Update your routine details" : "Set up a recurring daily routine",
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    detailsCard
                    scheduleCard
                    repeatCard
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
                confirmTitle: isEditing ? "Save Routine" : "Create Routine",
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
            if let error { Text(error) }
        }
        .onAppear { loadRoutine() }
    }

    // MARK: - Cards

    private var detailsCard: some View {
        CreationSectionCard(title: "Details", icon: "square.and.pencil") {
            VStack(spacing: AppTheme.Space.sm) {
                TextField("Routine name", text: $title)
                    .focused($focusedField, equals: .title)
                    .designField(isFocused: focusedField == .title)

                pickerRow("Category", selection: $category) {
                    ForEach(TaskCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
            }
        }
    }

    private var scheduleCard: some View {
        CreationSectionCard(title: "Time", icon: "clock") {
            VStack(spacing: AppTheme.Space.sm) {
                toggleRow("Default Time", isOn: $hasTime)

                if hasTime {
                    timeRow("Start Time", selection: $startTime)
                    toggleRow("End Time", isOn: $hasEndTime)
                    if hasEndTime {
                        timeRow("End Time", selection: $endTime, minDate: startTime)
                    }
                }

                Text("Set a default time for when this routine should start")
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
    }

    private var repeatCard: some View {
        CreationSectionCard(title: "Repeat", icon: "repeat") {
            VStack(spacing: AppTheme.Space.sm) {
                pickerRow("Repeat", selection: $repeatPattern) {
                    ForEach(RepeatPattern.allCases, id: \.self) { pattern in
                        Text(pattern.displayName).tag(pattern)
                    }
                }

                if repeatPattern == .custom {
                    VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                        Text("Select days")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(AppTheme.onSurfaceVariant)

                        dayOfWeekPills
                    }

                    CreationInlineError(
                        text: selectedDays.isEmpty ? "Select at least one day" : nil
                    )
                }
            }
        }
    }

    private var dayOfWeekPills: some View {
        HStack(spacing: AppTheme.Space.sm) {
            ForEach(DayOfWeek.allCases.sorted { $0.rawValue < $1.rawValue }, id: \.self) { day in
                let isSelected = selectedDays.contains(day)
                Button {
                    if isSelected {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    Text(day.shortName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AppTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Space.sm)
                        .background(isSelected ? AnyShapeStyle(AppTheme.dayPlannerGradient) : AnyShapeStyle(AppTheme.surfaceContainer))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notesCard: some View {
        CreationSectionCard(title: "Notes", icon: "note.text") {
            TextField("Add notes...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .focused($focusedField, equals: .notes)
                .designField(isFocused: focusedField == .notes)
        }
    }

    // MARK: - Reusable Row Helpers

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(AppTheme.TextStyle.body)
            .tint(AppTheme.primary)
            .padding(.horizontal, AppTheme.Space.md)
            .padding(.vertical, AppTheme.Space.sm)
            .background(AppTheme.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func timeRow(_ label: String, selection: Binding<Date>, minDate: Date? = nil) -> some View {
        HStack {
            Text(label)
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
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pickerRow<T: Hashable, Content: View>(
        _ label: String,
        selection: Binding<T>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
            Spacer()
            Picker(label, selection: selection) {
                content()
            }
            .pickerStyle(.menu)
            .tint(AppTheme.primary)
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Load & Save

    private func loadRoutine() {
        if let routine {
            title = routine.title
            hasTime = routine.startTime != nil
            startTime = routine.startTime ?? Date()
            hasEndTime = routine.endTime != nil
            endTime = routine.endTime ?? Date().addingTimeInterval(3600)
            category = routine.category
            repeatPattern = routine.repeatPattern
            selectedDays = routine.selectedDays
            notes = routine.notes
        } else {
            let calendar = Calendar.current
            startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            endTime = startTime.addingTimeInterval(3600)
        }
    }

    private func save() async {
        isSaving = true

        do {
            let newRoutine = DailyRoutine(
                id: routine?.id ?? UUID(),
                title: title.trimmingCharacters(in: .whitespaces),
                startTime: hasTime ? startTime : nil,
                endTime: hasTime && hasEndTime ? endTime : nil,
                category: category,
                repeatPattern: repeatPattern,
                selectedDays: repeatPattern == .custom ? selectedDays : [],
                isEnabled: routine?.isEnabled ?? true,
                notes: notes,
                createdAt: routine?.createdAt ?? Date()
            )

            if isEditing {
                try await service.updateRoutine(newRoutine)
            } else {
                try await service.createRoutine(newRoutine)
            }

            dismiss()
        } catch {
            self.error = error.localizedDescription
            showError = true
        }

        isSaving = false
    }
}

#Preview("New Routine") {
    RoutineFormView(
        service: DayPlannerService(
            taskRepository: LocalDailyTaskRepository(),
            routineRepository: LocalDailyRoutineRepository()
        ),
        routine: nil
    )
}

#Preview("Edit Routine") {
    RoutineFormView(
        service: DayPlannerService(
            taskRepository: LocalDailyTaskRepository(),
            routineRepository: LocalDailyRoutineRepository()
        ),
        routine: DailyRoutine(
            title: "Morning Workout",
            startTime: Date(),
            category: .health,
            repeatPattern: .weekdays
        )
    )
}
