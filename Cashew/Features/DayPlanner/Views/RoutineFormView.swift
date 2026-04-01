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

    private var isEditing: Bool { routine != nil }

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let hasValidDays = repeatPattern != .custom || !selectedDays.isEmpty
        return hasTitle && hasValidDays
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                scheduleSection
                repeatSection
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
            .navigationTitle(isEditing ? "Edit Routine" : "New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
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
            .onAppear {
                loadRoutine()
            }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            TextField("Routine name", text: $title)

            Picker("Category", selection: $category) {
                ForEach(TaskCategory.allCases, id: \.self) { cat in
                    Label(cat.displayName, systemImage: cat.icon)
                        .tag(cat)
                }
            }
        } header: {
            Text("Details")
        }
    }

    private var scheduleSection: some View {
        Section {
            Toggle("Default Time", isOn: $hasTime)

            if hasTime {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                Toggle("End Time", isOn: $hasEndTime)

                if hasEndTime {
                    DatePicker("End Time", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                }
            }
        } header: {
            Text("Time")
        } footer: {
            Text("Set a default time for when this routine should start")
        }
    }

    private var repeatSection: some View {
        Section {
            Picker("Repeat", selection: $repeatPattern) {
                ForEach(RepeatPattern.allCases, id: \.self) { pattern in
                    Text(pattern.displayName).tag(pattern)
                }
            }

            if repeatPattern == .custom {
                NavigationLink {
                    DayOfWeekPicker(selectedDays: $selectedDays)
                } label: {
                    HStack {
                        Text("Days")
                        Spacer()
                        Text(selectedDaysText)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }
            }
        } header: {
            Text("Repeat")
        } footer: {
            if repeatPattern == .custom && selectedDays.isEmpty {
                Text("Select at least one day")
                    .foregroundStyle(AppTheme.negative)
            }
        }
    }

    private var selectedDaysText: String {
        if selectedDays.isEmpty {
            return "None"
        }
        if selectedDays.count == 7 {
            return "Every day"
        }
        return selectedDays
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.shortName }
            .joined(separator: ", ")
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
            // Default start time to 9 AM
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
