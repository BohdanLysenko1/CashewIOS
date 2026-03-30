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
    @State private var confettiSubtaskID: UUID?
    @FocusState private var isNotesFocused: Bool
    @FocusState private var isSubtaskFocused: Bool

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

    private var subtaskProgress: Double {
        guard !liveTask.subtasks.isEmpty else { return 0 }
        return Double(liveTask.completedSubtaskCount) / Double(liveTask.subtasks.count)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    heroCard
                    scheduleCard
                    notesCard
                    subtasksCard
                    if linkedTripName != nil || linkedEventTitle != nil {
                        linksCard
                    }
                    metaCard
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.vertical, AppTheme.Space.md)
            }
            .background(AppTheme.background)
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
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
            // Keep local notes in sync if the edit form changes them.
            .onChange(of: liveTask.notes) { _, updated in
                notes = updated
            }
            .fullScreenCover(isPresented: $showEditForm) {
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

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            HStack(alignment: .top, spacing: AppTheme.Space.md) {
                Image(systemName: liveTask.category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(liveTask.title)
                        .font(AppTheme.TextStyle.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        heroChip(icon: liveTask.category.icon, label: liveTask.categoryDisplayName)
                        if liveTask.routineId != nil {
                            heroChip(icon: "repeat", label: "Routine")
                        }
                    }
                }

                Spacer(minLength: 0)
                statusChip
            }

            HStack(spacing: 8) {
                heroChip(icon: "calendar", label: liveTask.date.formatted(date: .abbreviated, time: .omitted))
                if let timeRange = liveTask.formattedTimeRange {
                    heroChip(icon: "clock.fill", label: timeRange)
                }
                if let duration = liveTask.duration {
                    heroChip(icon: "hourglass", label: formattedDuration(duration))
                }
            }

            if liveTask.hasSubtasks {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Subtasks")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer()
                        Text("\(liveTask.completedSubtaskCount)/\(liveTask.subtasks.count)")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(.white.opacity(0.92))
                    }

                    AppProgressBar(progress: subtaskProgress, color: .white, animated: true)
                        .frame(height: AppTheme.progressBarHeight)
                }
            }
        }
        .padding(AppTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.dayPlannerGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: AppTheme.primary.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    private func heroChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(AppTheme.TextStyle.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.16))
        .clipShape(Capsule())
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            Image(systemName: liveTask.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .semibold))
            Text(liveTask.isCompleted ? "Completed" : "Pending")
                .font(AppTheme.TextStyle.captionBold)
        }
        .foregroundStyle(liveTask.isCompleted ? .green : .white.opacity(0.96))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(liveTask.isCompleted ? Color.white.opacity(0.95) : Color.white.opacity(0.18))
        .clipShape(Capsule())
    }

    // MARK: - Cards

    private var scheduleCard: some View {
        sectionCard("Schedule", icon: "clock.fill") {
            VStack(spacing: 12) {
                detailLine(
                    icon: "calendar",
                    tint: .blue,
                    title: "Date",
                    value: liveTask.date.formatted(date: .long, time: .omitted)
                )

                if let timeRange = liveTask.formattedTimeRange {
                    detailLine(icon: "clock.fill", tint: .purple, title: "Time", value: timeRange)
                } else {
                    detailLine(icon: "clock.fill", tint: .gray, title: "Time", value: "No specific time")
                }

                if let duration = liveTask.duration {
                    detailLine(
                        icon: "hourglass",
                        tint: .orange,
                        title: "Duration",
                        value: formattedDuration(duration)
                    )
                }
            }
        }
    }

    private var notesCard: some View {
        sectionCard("Notes", icon: "note.text") {
            TextField("Add notes...", text: $notes, axis: .vertical)
                .focused($isNotesFocused)
                .lineLimit(4...10)
                .designField(isFocused: isNotesFocused)
                .onChange(of: notes) { _, newValue in
                    saveNotes(newValue)
                }
        }
    }

    private var subtasksCard: some View {
        sectionCard("Subtasks", icon: "checklist") {
            VStack(spacing: AppTheme.Space.sm) {
                if liveTask.subtasks.isEmpty {
                    Text("No subtasks yet")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(liveTask.subtasks) { subtask in
                        subtaskRow(subtask)
                    }

                    HStack {
                        Text("\(liveTask.completedSubtaskCount) of \(liveTask.subtasks.count) completed")
                            .font(AppTheme.TextStyle.caption)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        Spacer()
                    }
                    .padding(.top, 4)
                }

                if showAddSubtask {
                    HStack(spacing: AppTheme.Space.sm) {
                        TextField("New subtask...", text: $newSubtaskTitle)
                            .focused($isSubtaskFocused)
                            .submitLabel(.done)
                            .onSubmit { commitSubtask() }
                            .designField(isFocused: isSubtaskFocused)

                        Button("Add") {
                            commitSubtask()
                        }
                        .font(AppTheme.TextStyle.bodyBold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AnyShapeStyle(AppTheme.onSurfaceVariant.opacity(0.20))
                                : AnyShapeStyle(AppTheme.dayPlannerGradient)
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Button {
                    withAnimation(.spring(response: AppTheme.springResponse, dampingFraction: 0.7)) {
                        showAddSubtask = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isSubtaskFocused = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Subtask")
                            .font(AppTheme.TextStyle.bodyBold)
                    }
                    .foregroundStyle(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func subtaskRow(_ subtask: Subtask) -> some View {
        HStack(spacing: 10) {
            Button {
                triggerSubtaskToggle(subtask)
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(subtask.isCompleted ? .green : AppTheme.onSurfaceVariant)
                    .symbolEffect(.bounce, value: subtask.isCompleted)
            }
            .buttonStyle(.plain)

            Text(subtask.title)
                .font(AppTheme.TextStyle.body)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? AppTheme.onSurfaceVariant : AppTheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                deleteSubtask(subtask.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            if confettiSubtaskID == subtask.id {
                ConfettiView()
                    .offset(x: 26)
            }
        }
    }

    private var linksCard: some View {
        sectionCard("Linked To", icon: "link") {
            VStack(spacing: 12) {
                if let tripName = linkedTripName {
                    detailLine(icon: "airplane", tint: AppTheme.secondary, title: "Trip", value: tripName)
                }
                if let eventTitle = linkedEventTitle {
                    detailLine(icon: "star.fill", tint: AppTheme.tertiary, title: "Event", value: eventTitle)
                }
            }
        }
    }

    private var metaCard: some View {
        sectionCard("Info", icon: "clock.arrow.circlepath") {
            VStack(spacing: 12) {
                detailLine(
                    icon: "clock.badge.checkmark",
                    tint: AppTheme.onSurfaceVariant,
                    title: "Created",
                    value: liveTask.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
                detailLine(
                    icon: "pencil.circle.fill",
                    tint: AppTheme.onSurfaceVariant,
                    title: "Updated",
                    value: liveTask.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    // MARK: - Card helpers

    private func sectionCard<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            SectionHeader(icon: icon, title: title, gradient: AppTheme.dayPlannerGradient)
            content()
        }
        .padding(AppTheme.Space.lg)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 16, x: 0, y: 6)
    }

    private func detailLine(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)

            Spacer(minLength: 10)

            Text(value)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Actions

    private func triggerSubtaskToggle(_ subtask: Subtask) {
        let completing = !subtask.isCompleted

        if completing {
            HapticManager.notification(.success)
            confettiSubtaskID = subtask.id
            Task {
                try? await Task.sleep(for: .seconds(AppTheme.confettiLifetime))
                if confettiSubtaskID == subtask.id {
                    confettiSubtaskID = nil
                }
            }
        } else {
            HapticManager.impact(.light)
        }

        toggleSubtask(subtask.id)
    }

    private func toggleSubtask(_ subtaskId: UUID) {
        Task {
            do { try await service.toggleSubtask(subtaskId, in: liveTask) }
            catch { print("[TaskDetailView] Failed to toggle subtask: \(error)") }
        }
    }

    private func deleteSubtask(_ subtaskId: UUID) {
        Task {
            do { try await service.deleteSubtask(subtaskId, from: liveTask) }
            catch { print("[TaskDetailView] Failed to delete subtask: \(error)") }
        }
    }

    private func commitSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard newNotes != liveTask.notes else { return }
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
