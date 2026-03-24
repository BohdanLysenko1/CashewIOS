import SwiftUI

struct DayPlannerView: View {

    @Environment(AppContainer.self) private var container
    @State private var showAddTask = false
    @State private var showRoutines = false
    @State private var detailTask: DailyTask?
    @State private var editingTask: DailyTask?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isSelectMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    private var service: DayPlannerServiceProtocol {
        container.dayPlannerService
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Date selector
                    dateSelector

                    // Content
                    if isLoading {
                        loadingView
                    } else {
                        contentView
                    }
                }

                if isSelectMode && !selectedTasks.isEmpty {
                    deleteBar
                }
            }
            .background(AppTheme.background)
            .navigationTitle("My Day")
            .toolbar {
                if isSelectMode {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            withAnimation {
                                isSelectMode = false
                                selectedTasks.removeAll()
                            }
                        }
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button(selectedTasks.count == service.tasksForSelectedDate.count ? "Deselect All" : "Select All") {
                            if selectedTasks.count == service.tasksForSelectedDate.count {
                                selectedTasks.removeAll()
                            } else {
                                selectedTasks = Set(service.tasksForSelectedDate.map(\.id))
                            }
                        }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showAddTask = true
                            } label: {
                                Label("Add Task", systemImage: "plus")
                            }

                            Button {
                                showRoutines = true
                            } label: {
                                Label("Manage Routines", systemImage: "repeat")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }

                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            withAnimation {
                                isSelectMode = true
                            }
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                DailyTaskFormView(
                    service: service,
                    tripService: container.tripService,
                    eventService: container.eventService,
                    task: nil,
                    defaultDate: service.selectedDate
                )
            }
            .sheet(item: $detailTask) { task in
                TaskDetailView(
                    task: task,
                    service: service,
                    tripService: container.tripService,
                    eventService: container.eventService
                )
            }
            .sheet(item: $editingTask) { task in
                DailyTaskFormView(
                    service: service,
                    tripService: container.tripService,
                    eventService: container.eventService,
                    task: task,
                    defaultDate: service.selectedDate
                )
            }
            .sheet(isPresented: $showRoutines) {
                RoutinesListView(service: service)
            }
            .confirmationDialog(
                "Delete \(selectedTasks.count) Task\(selectedTasks.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedTasks()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dateRange, id: \.self) { date in
                        DateTab(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: service.selectedDate),
                            taskCount: tasksCount(for: date)
                        )
                        .id(date)
                        .onTapGesture {
                            withAnimation {
                                service.selectedDate = date
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(AppTheme.surfaceContainerLowest)
            .onAppear {
                let today = Calendar.current.startOfDay(for: service.selectedDate)
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo(today, anchor: .leading)
                }
            }
            .onChange(of: service.selectedDate) { _, newDate in
                selectedTasks.removeAll()
                let normalized = Calendar.current.startOfDay(for: newDate)
                withAnimation {
                    proxy.scrollTo(normalized, anchor: .leading)
                }
            }
        }
    }

    private var dateRange: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var dates: [Date] = []

        // 7 days before and 14 days after
        for offset in -7...14 {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                dates.append(date)
            }
        }

        return dates
    }

    private func tasksCount(for date: Date) -> Int {
        let calendar = Calendar.current
        return service.allTasks.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Today's summary
                summaryCard

                // Scheduled tasks (timeline)
                if !service.scheduledTasks.isEmpty {
                    scheduledSection
                }

                // Unscheduled tasks (to-do list)
                if !service.unscheduledTasks.isEmpty {
                    todoSection
                }

                // Empty state
                if service.tasksForSelectedDate.isEmpty {
                    emptyStateView
                }

            }
            .padding()
            .padding(.bottom, isSelectMode && !selectedTasks.isEmpty ? 60 : 0)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    let completed = service.tasksForSelectedDate.filter { $0.isCompleted }.count
                    let total = service.tasksForSelectedDate.count

                    if total > 0 {
                        Text("\(completed) of \(total) tasks completed")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    } else {
                        Text("No tasks planned")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }

                Spacer()

                if !service.tasksForSelectedDate.isEmpty {
                    progressRing
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    private var dateTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(service.selectedDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(service.selectedDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(service.selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: service.selectedDate)
        }
    }

    private var progressRing: some View {
        let completed = service.tasksForSelectedDate.filter { $0.isCompleted }.count
        let total = service.tasksForSelectedDate.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0

        return ZStack {
            Circle()
                .stroke(AppTheme.surfaceContainerHigh, lineWidth: 6)
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor(progress).gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
        }
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress == 1.0 { return .green }
        if progress > 0.5 { return .blue }
        return .orange
    }

    // MARK: - Scheduled Section

    private var scheduledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Schedule", icon: "clock.fill")

            if isSelectMode {
                VStack(spacing: 0) {
                    ForEach(service.scheduledTasks) { task in
                        selectableTaskRow(task)
                    }
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            } else {
                ScheduleTimelineView(
                    tasks: service.scheduledTasks,
                    linkResolver: { task in
                        guard let icon = linkIcon(for: task), let label = linkLabel(for: task) else { return nil }
                        return (icon, label)
                    },
                    onToggle: { task in toggleTask(task) },
                    onDetail: { task in detailTask = task },
                    onEdit: { task in editingTask = task },
                    onDelete: { task in deleteTask(task) }
                )
            }
        }
    }

    // MARK: - To-Do Section

    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("To-Do", icon: "checklist")
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(service.unscheduledTasks) { task in
                    if isSelectMode {
                        selectableTaskRow(task)
                    } else {
                        DailyTaskRow(
                            task: task,
                            linkIcon: linkIcon(for: task),
                            linkLabel: linkLabel(for: task),
                            onToggle: { toggleTask(task) },
                            onSubtaskToggle: { subtaskId in toggleSubtask(subtaskId, in: task) },
                            onDetail: { detailTask = task },
                            onEdit: { editingTask = task },
                            onDelete: { deleteTask(task) }
                        )
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.onSurfaceVariant)

            VStack(spacing: 6) {
                Text("No Tasks Planned")
                    .font(.headline)

                Text("Add tasks to plan your day")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Button {
                showAddTask = true
            } label: {
                Label("Add Task", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        }
    }

    // MARK: - Selectable Row

    private func selectableTaskRow(_ task: DailyTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(selectedTasks.contains(task.id) ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Image(systemName: task.category.icon)
                        .font(.caption2)
                    Text(task.categoryDisplayName)
                        .font(.caption)
                }
                .foregroundStyle(task.category.color)

                if let icon = linkIcon(for: task), let label = linkLabel(for: task) {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.caption2)
                        Text(label)
                            .font(.caption)
                    }
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                if selectedTasks.contains(task.id) {
                    selectedTasks.remove(task.id)
                } else {
                    selectedTasks.insert(task.id)
                }
            }
        }
    }

    // MARK: - Link Helpers

    private func linkLabel(for task: DailyTask) -> String? {
        if let tripId = task.tripId, let trip = container.tripService.trip(by: tripId) {
            return trip.name
        }
        if let eventId = task.eventId, let event = container.eventService.event(by: eventId) {
            return event.title
        }
        return nil
    }

    private func linkIcon(for task: DailyTask) -> String? {
        if task.tripId != nil { return "airplane" }
        if task.eventId != nil { return "star" }
        return nil
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        do {
            try await service.loadData()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleTask(_ task: DailyTask) {
        Task {
            do { try await service.toggleTaskCompletion(task) }
            catch { print("[DayPlannerView] Failed to toggle task: \(error)") }
        }
    }

    private func toggleSubtask(_ subtaskId: UUID, in task: DailyTask) {
        Task {
            do { try await service.toggleSubtask(subtaskId, in: task) }
            catch { print("[DayPlannerView] Failed to toggle subtask: \(error)") }
        }
    }

    private func deleteTask(_ task: DailyTask) {
        Task {
            do { try await service.deleteTask(by: task.id) }
            catch { print("[DayPlannerView] Failed to delete task: \(error)") }
        }
    }

    private func deleteSelectedTasks() {
        let idsToDelete = selectedTasks
        Task {
            for id in idsToDelete {
                do { try await service.deleteTask(by: id) }
                catch { print("[DayPlannerView] Failed to delete task \(id): \(error)") }
            }
            withAnimation {
                selectedTasks.removeAll()
                isSelectMode = false
            }
        }
    }

    // MARK: - Delete Bar

    private var deleteBar: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete \(selectedTasks.count) Task\(selectedTasks.count == 1 ? "" : "s")")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Date Tab

private struct DateTab: View {
    let date: Date
    let isSelected: Bool
    let taskCount: Int

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(Self.dayFormatter.string(from: date))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(Self.dateFormatter.string(from: date))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))

            if taskCount > 0 {
                Text("\(taskCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .blue)
            }
        }
        .frame(width: 50, height: 70)
        .background(isSelected ? AppTheme.primary : (isToday ? AppTheme.primary.opacity(0.1) : AppTheme.surfaceContainerLow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DayPlannerView()
        .environment(AppContainer())
}
