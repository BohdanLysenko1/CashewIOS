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
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showRoutines = true
                            } label: {
                                Label("Manage Routines", systemImage: "repeat")
                            }

                            Button {
                                withAnimation {
                                    isSelectMode = true
                                }
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddTask) {
                TaskCreationWizardView(
                    service: service,
                    tripService: container.tripService,
                    eventService: container.eventService,
                    defaultDate: service.selectedDate,
                    onCreated: { _ in },
                    onDismiss: { showAddTask = false }
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
            .fullScreenCover(item: $editingTask) { task in
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
                .padding(.horizontal, AppTheme.Space.lg)
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
            LazyVStack(spacing: AppTheme.Space.lg) {
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
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.top, AppTheme.Space.md)
            .padding(.bottom, isSelectMode && !selectedTasks.isEmpty ? 84 : AppTheme.Space.lg)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let completed = service.tasksForSelectedDate.filter { $0.isCompleted }.count
        let total = service.tasksForSelectedDate.count

        return VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            HStack(alignment: .top, spacing: AppTheme.Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateTitle)
                        .font(AppTheme.TextStyle.title)
                        .foregroundStyle(AppTheme.onSurface)

                    if total > 0 {
                        Text("\(completed) of \(total) tasks completed")
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    } else {
                        Text("No tasks planned")
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }

                Spacer()

                if !service.tasksForSelectedDate.isEmpty {
                    progressRing
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 94), spacing: AppTheme.Space.sm)],
                spacing: AppTheme.Space.sm
            ) {
                summaryMetricChip(
                    icon: "clock.fill",
                    title: "Scheduled",
                    value: "\(service.scheduledTasks.count)",
                    tint: AppTheme.primary
                )
                summaryMetricChip(
                    icon: "checklist",
                    title: "To-Do",
                    value: "\(service.unscheduledTasks.count)",
                    tint: AppTheme.secondary
                )
                summaryMetricChip(
                    icon: "checkmark.circle.fill",
                    title: "Done",
                    value: "\(completed)",
                    tint: .green
                )
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 16, x: 0, y: 6)
    }

    private func summaryMetricChip(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(AppTheme.TextStyle.caption)
            }
            .foregroundStyle(tint)

            Text(value)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            sectionHeader("Schedule", icon: "clock.fill", count: service.scheduledTasks.count)

            if isSelectMode {
                VStack(spacing: AppTheme.Space.sm) {
                    ForEach(service.scheduledTasks) { task in
                        selectableTaskRow(task)
                    }
                }
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
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            sectionHeader("To-Do", icon: "checklist", count: service.unscheduledTasks.count)

            VStack(spacing: AppTheme.Space.sm) {
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
        }
    }

    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack(spacing: AppTheme.Space.sm) {
            SectionHeader(icon: icon, title: title, gradient: AppTheme.dayPlannerGradient)
            Text("\(count)")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.surfaceContainerHigh)
                .clipShape(Capsule())
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.dayPlannerGradient)

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
                    .primaryActionButton(gradient: AppTheme.dayPlannerGradient, fullWidth: false)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
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
        let isSelected = selectedTasks.contains(task.id)

        return HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)
                    .lineLimit(2)

                selectionMetadata(for: task)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.md)
        .background(isSelected ? AppTheme.primary.opacity(0.10) : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? AppTheme.primary.opacity(0.35) : AppTheme.outlineVariant, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                if isSelected {
                    selectedTasks.remove(task.id)
                } else {
                    selectedTasks.insert(task.id)
                }
            }
        }
    }

    private func selectionChip(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(AppTheme.TextStyle.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }

    private func selectionMetadata(for task: DailyTask) -> some View {
        ViewThatFits(in: .horizontal) {
            selectionMetadataRow(for: task, includeLink: true)
            selectionMetadataRow(for: task, includeLink: false)
        }
    }

    @ViewBuilder
    private func selectionMetadataRow(for task: DailyTask, includeLink: Bool) -> some View {
        HStack(spacing: AppTheme.Space.xs) {
            selectionChip(icon: task.category.icon, label: task.categoryDisplayName, tint: task.category.color)

            if task.routineId != nil {
                RoutineBadge()
            }

            if let timeRange = task.formattedTimeRange {
                selectionChip(icon: "clock.fill", label: timeRange, tint: AppTheme.onSurfaceVariant)
            }

            if includeLink, let icon = linkIcon(for: task), let label = linkLabel(for: task) {
                selectionChip(icon: icon, label: label, tint: AppTheme.onSurfaceVariant)
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
        DestructiveSelectionBar(
            title: "Delete \(selectedTasks.count) Task\(selectedTasks.count == 1 ? "" : "s")"
        ) {
            showDeleteConfirmation = true
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
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 5) {
                Text(Self.dayFormatter.string(from: date))
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : AppTheme.onSurfaceVariant)

                Text(Self.dateFormatter.string(from: date))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? .white : (isToday ? AppTheme.primary : AppTheme.onSurface))

                Circle()
                    .fill(isSelected ? .white.opacity(0.85) : (taskCount > 0 ? AppTheme.primary : .clear))
                    .frame(width: 6, height: 6)
            }
            .frame(width: 64, height: 78)
            .background(
                isSelected
                    ? AnyShapeStyle(AppTheme.dayPlannerGradient)
                    : AnyShapeStyle(isToday ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceContainerLow)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? AppTheme.primary.opacity(0.25) : Color.clear, lineWidth: 1)
            )

            if taskCount > 0 {
                Text("\(taskCount)")
                    .font(AppTheme.TextStyle.micro)
                    .foregroundStyle(isSelected ? AppTheme.primary : .white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isSelected ? AppTheme.onPrimary : AppTheme.primary)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
            }
        }
        .shadow(color: isSelected ? AppTheme.primary.opacity(0.18) : .clear, radius: 10, x: 0, y: 5)
    }
}

#Preview {
    DayPlannerView()
        .environment(AppContainer())
}
