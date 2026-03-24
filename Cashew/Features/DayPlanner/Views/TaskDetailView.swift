import SwiftUI

struct TaskDetailView: View {

    @Environment(\.dismiss) private var dismiss

    let task: DailyTask
    let service: DayPlannerServiceProtocol
    let tripService: TripServiceProtocol
    let eventService: EventServiceProtocol

    @State private var notes: String = ""
    @State private var newSubtaskTitle: String = ""
    @State private var showAddSubtask = false
    @State private var showEditForm = false

    // MARK: - Live task (re-renders when service updates)

    /// Always reads the latest version from the service so subtask toggles
    /// and other mutations are reflected immediately.
    private var liveTask: DailyTask {
        service.allTasks.first { $0.id == task.id } ?? task
    }

    // MARK: - Computed helpers

    private var linkedTripName: String? {
        guard let tripId = liveTask.tripId else { return nil }
        return tripService.trip(by: tripId)?.name
    }

    private var linkedEventTitle: String? {
        guard let eventId = liveTask.eventId else { return nil }
        return eventService.event(by: eventId)?.title
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                headerSection
                scheduleSection
                notesSection
                subtasksSection
                if linkedTripName != nil || linkedEventTitle != nil { linksSection }
                metaSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(liveTask.title)
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditForm = true }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .onAppear {
                notes = liveTask.notes
            }
            // Keep local notes in sync if the edit form changes them
            .onChange(of: liveTask.notes) { _, updated in
                notes = updated
            }
            .sheet(isPresented: $showEditForm) {
                DailyTaskFormView(
                    service: service,
                    tripService: tripService,
                    eventService: eventService,
                    task: liveTask,
                    defaultDate: liveTask.date
                )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(liveTask.category.color.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: liveTask.category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(liveTask.category.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(liveTask.categoryDisplayName)
                        .font(.caption)
                        .foregroundStyle(liveTask.category.color)
                        .fontWeight(.semibold)

                    if liveTask.routineId != nil {
                        RoutineBadge()
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: liveTask.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(liveTask.isCompleted ? .green : AppTheme.onSurfaceVariant)
                    Text(liveTask.isCompleted ? "Completed" : "Pending")
                        .font(.caption)
                        .foregroundStyle(liveTask.isCompleted ? .green : AppTheme.onSurfaceVariant)
                }
                .fontWeight(.medium)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Schedule Section

    @ViewBuilder
    private var scheduleSection: some View {
        Section("Schedule") {
            LabeledContent {
                Text(liveTask.date, style: .date)
                    .foregroundStyle(AppTheme.onSurface)
            } label: {
                Label("Date", systemImage: "calendar")
            }

            if let timeRange = liveTask.formattedTimeRange {
                LabeledContent {
                    Text(timeRange)
                        .foregroundStyle(AppTheme.onSurface)
                } label: {
                    Label("Time", systemImage: "clock")
                }
            }

            if let duration = liveTask.duration {
                LabeledContent {
                    Text(formattedDuration(duration))
                        .foregroundStyle(AppTheme.onSurface)
                } label: {
                    Label("Duration", systemImage: "hourglass")
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        Section("Notes") {
            TextField("Add notes...", text: $notes, axis: .vertical)
                .lineLimit(3...10)
                .onChange(of: notes) { _, newValue in
                    saveNotes(newValue)
                }
        }
    }

    // MARK: - Subtasks Section

    private var subtasksSection: some View {
        Section {
            ForEach(liveTask.subtasks) { subtask in
                HStack(spacing: 12) {
                    Button {
                        toggleSubtask(subtask.id)
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(subtask.isCompleted ? .green : AppTheme.onSurfaceVariant)
                            .symbolEffect(.bounce, value: subtask.isCompleted)
                    }
                    .buttonStyle(.plain)

                    Text(subtask.title)
                        .font(.body)
                        .strikethrough(subtask.isCompleted)
                        .foregroundStyle(subtask.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                        .animation(.easeInOut(duration: 0.2), value: subtask.isCompleted)

                    Spacer()
                }
                .padding(.vertical, 2)
            }

            if showAddSubtask {
                HStack {
                    TextField("New subtask...", text: $newSubtaskTitle)
                        .submitLabel(.done)
                        .onSubmit { commitSubtask() }

                    Button("Add") { commitSubtask() }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Button {
                showAddSubtask = true
            } label: {
                Label("Add Subtask", systemImage: "plus.circle")
            }
        } header: {
            Text("Subtasks")
        } footer: {
            if !liveTask.subtasks.isEmpty {
                let done = liveTask.completedSubtaskCount
                let total = liveTask.subtasks.count
                Text("\(done) of \(total) completed")
            }
        }
    }

    // MARK: - Links Section

    private var linksSection: some View {
        Section("Linked To") {
            if let tripName = linkedTripName {
                Label(tripName, systemImage: "airplane")
            }
            if let eventTitle = linkedEventTitle {
                Label(eventTitle, systemImage: "star")
            }
        }
    }

    // MARK: - Meta Section

    private var metaSection: some View {
        Section {
            LabeledContent {
                Text(liveTask.createdAt, style: .date)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            } label: {
                Label("Created", systemImage: "clock.badge.checkmark")
            }
        }
        .foregroundStyle(AppTheme.onSurfaceVariant)
    }

    // MARK: - Actions

    private func toggleSubtask(_ subtaskId: UUID) {
        Task {
            do { try await service.toggleSubtask(subtaskId, in: liveTask) }
            catch { print("[TaskDetailView] Failed to toggle subtask: \(error)") }
        }
    }

    private func commitSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                try await service.addSubtask(title: trimmed, to: liveTask)
                newSubtaskTitle = ""
                showAddSubtask = false
                HapticManager.impact(.light)
            } catch {
                print("[TaskDetailView] Failed to add subtask: \(error)")
            }
        }
    }

    private func saveNotes(_ newNotes: String) {
        var updated = liveTask
        updated.notes = newNotes
        Task {
            do { try await service.updateTask(updated) }
            catch { print("[TaskDetailView] Failed to save notes: \(error)") }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}

#Preview {
    let container = AppContainer()
    TaskDetailView(
        task: DailyTask(
            title: "Team Meeting",
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            category: .work,
            notes: "Discuss Q2 roadmap and sprint planning.",
            subtasks: [
                Subtask(title: "Prepare slides", isCompleted: true),
                Subtask(title: "Send agenda"),
                Subtask(title: "Book conference room")
            ]
        ),
        service: container.dayPlannerService,
        tripService: container.tripService,
        eventService: container.eventService
    )
}
