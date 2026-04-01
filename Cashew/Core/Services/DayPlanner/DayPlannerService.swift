import Foundation
import Observation

@Observable
@MainActor
final class DayPlannerService: DayPlannerServiceProtocol {

    private let taskRepository: DailyTaskRepositoryProtocol
    private let routineRepository: DailyRoutineRepositoryProtocol
    private let gamificationService: GamificationService?
    private let notificationScheduler: NotificationScheduler?

    private(set) var allTasks: [DailyTask] = []
    private(set) var routines: [DailyRoutine] = []
    private var dateChangeTask: Task<Void, Never>?

    var selectedDate: Date = Date() {
        didSet {
            dateChangeTask?.cancel()
            dateChangeTask = Task {
                do { try await generateTasksFromRoutines(for: selectedDate) }
                catch is CancellationError { }
                catch { print("[DayPlannerService] Failed to generate tasks for \(selectedDate): \(error)") }
            }
        }
    }

    // MARK: - Computed Properties

    var tasksForSelectedDate: [DailyTask] {
        let calendar = Calendar.current
        return allTasks
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { task1, task2 in
                // Scheduled tasks first, sorted by time
                if let time1 = task1.startTime, let time2 = task2.startTime {
                    return time1 < time2
                }
                if task1.startTime != nil { return true }
                if task2.startTime != nil { return false }
                // Unscheduled: sort by creation time (completed tasks stay in place)
                return task1.createdAt < task2.createdAt
            }
    }

    var scheduledTasks: [DailyTask] {
        tasksForSelectedDate.filter { $0.isScheduled }
    }

    var unscheduledTasks: [DailyTask] {
        tasksForSelectedDate.filter { !$0.isScheduled }
    }

    // MARK: - Init

    init(
        taskRepository: DailyTaskRepositoryProtocol,
        routineRepository: DailyRoutineRepositoryProtocol,
        gamificationService: GamificationService? = nil,
        notificationScheduler: NotificationScheduler? = nil
    ) {
        self.taskRepository = taskRepository
        self.routineRepository = routineRepository
        self.gamificationService = gamificationService
        self.notificationScheduler = notificationScheduler
    }

    // MARK: - Load Data

    func loadData() async throws {
        allTasks = try await taskRepository.fetchAll()
        routines = try await routineRepository.fetchAll()

        // Generate tasks from routines for today
        try await generateTasksFromRoutines(for: selectedDate)
    }

    // MARK: - Task CRUD

    func createTask(_ task: DailyTask) async throws {
        let savedTask = try await taskRepository.save(task)
        allTasks.append(savedTask)
        await notificationScheduler?.rescheduleTaskNotifications(tasks: allTasks)
    }

    func updateTask(_ task: DailyTask) async throws {
        let savedTask = try await taskRepository.save(task)
        if let index = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[index] = savedTask
        }
    }

    func deleteTask(by id: UUID) async throws {
        try await taskRepository.delete(by: id)
        allTasks.removeAll { $0.id == id }
        await notificationScheduler?.rescheduleTaskNotifications(tasks: allTasks)
    }

    func toggleTaskCompletion(_ task: DailyTask) async throws {
        let wasCompleted = task.isCompleted
        var updatedTask = task
        updatedTask.isCompleted.toggle()
        try await updateTask(updatedTask)

        if let gam = gamificationService {
            let xp = XPCalculator.xp(for: task)
            let streak = maxCurrentStreak()
            if wasCompleted {
                gam.deduct(xp: xp, streakDays: streak)
            } else {
                gam.award(xp: xp, streakDays: streak)
                await notificationScheduler?.scheduleLevelUpIfNeeded(gamificationService: gam)
            }
        }

        // Refresh task + streak notifications after completion toggle
        await notificationScheduler?.rescheduleTaskNotifications(tasks: allTasks)
        await notificationScheduler?.rescheduleStreakProtection(routines: routines, allTasks: allTasks)
    }

    // MARK: - Subtask Operations

    func toggleSubtask(_ subtaskId: UUID, in task: DailyTask) async throws {
        guard let taskIndex = allTasks.firstIndex(where: { $0.id == task.id }),
              let subtaskIndex = allTasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskId })
        else { return }

        let wasCompleting = !allTasks[taskIndex].subtasks[subtaskIndex].isCompleted
        allTasks[taskIndex].subtasks[subtaskIndex].isCompleted = wasCompleting

        // Award/deduct subtask XP
        if let gam = gamificationService {
            let streak = maxCurrentStreak()
            if wasCompleting {
                gam.award(xp: XPCalculator.subtaskXP, streakDays: streak)
                await notificationScheduler?.scheduleLevelUpIfNeeded(gamificationService: gam)
            } else {
                gam.deduct(xp: XPCalculator.subtaskXP, streakDays: streak)
            }
        }

        // Auto-complete parent when all subtasks done
        let allDone = allTasks[taskIndex].allSubtasksCompleted
        let parentWasCompleted = task.isCompleted
        if allDone && !parentWasCompleted {
            allTasks[taskIndex].isCompleted = true
            if let gam = gamificationService {
                gam.award(xp: XPCalculator.subtaskCompletionBonus, streakDays: maxCurrentStreak())
                await notificationScheduler?.scheduleLevelUpIfNeeded(gamificationService: gam)
            }
        } else if !allDone && parentWasCompleted {
            allTasks[taskIndex].isCompleted = false
            if let gam = gamificationService {
                gam.deduct(xp: XPCalculator.subtaskCompletionBonus, streakDays: maxCurrentStreak())
            }
        }

        try await updateTask(allTasks[taskIndex])
    }

    func addSubtask(title: String, to task: DailyTask) async throws {
        guard let index = allTasks.firstIndex(where: { $0.id == task.id }) else { return }
        allTasks[index].subtasks.append(Subtask(title: title))
        try await updateTask(allTasks[index])
    }

    func deleteSubtask(_ subtaskId: UUID, from task: DailyTask) async throws {
        guard let index = allTasks.firstIndex(where: { $0.id == task.id }) else { return }
        allTasks[index].subtasks.removeAll { $0.id == subtaskId }
        try await updateTask(allTasks[index])
    }

    // MARK: - Routine CRUD

    func createRoutine(_ routine: DailyRoutine) async throws {
        let savedRoutine = try await routineRepository.save(routine)
        routines.append(savedRoutine)

        // Generate task for today if applicable
        if savedRoutine.shouldRunOn(date: selectedDate) {
            let task = savedRoutine.createTask(for: selectedDate)
            try await createTask(task)
        }

        await notificationScheduler?.rescheduleRoutineNotifications(routines: routines, allTasks: allTasks)
    }

    func updateRoutine(_ routine: DailyRoutine) async throws {
        let savedRoutine = try await routineRepository.save(routine)
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = savedRoutine
        }

        // Update any existing tasks from this routine for today
        await updateRoutineTasksForToday(routine: savedRoutine)
        await notificationScheduler?.rescheduleRoutineNotifications(routines: routines, allTasks: allTasks)
    }

    func deleteRoutine(by id: UUID) async throws {
        // Delete tasks first so a failure doesn't orphan them after the routine is gone
        let tasksToRemove = allTasks.filter { $0.routineId == id }
        for task in tasksToRemove {
            try await deleteTask(by: task.id)
        }

        try await routineRepository.delete(by: id)
        routines.removeAll { $0.id == id }

        await notificationScheduler?.rescheduleRoutineNotifications(routines: routines, allTasks: allTasks)
    }

    func toggleRoutineEnabled(_ routine: DailyRoutine) async throws {
        var updatedRoutine = routine
        updatedRoutine.isEnabled.toggle()
        let savedRoutine = try await routineRepository.save(updatedRoutine)
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = savedRoutine
        }

        let calendar = Calendar.current
        if savedRoutine.isEnabled {
            // Re-generate task for today if applicable
            if savedRoutine.shouldRunOn(date: selectedDate) {
                let existingTask = allTasks.first {
                    $0.routineId == savedRoutine.id && calendar.isDate($0.date, inSameDayAs: selectedDate)
                }
                if existingTask == nil {
                    let task = savedRoutine.createTask(for: selectedDate)
                    try await createTask(task)
                }
            }
        } else {
            // Remove all tasks generated from this routine
            let tasksToRemove = allTasks.filter { $0.routineId == routine.id }
            for task in tasksToRemove {
                try await deleteTask(by: task.id)
            }
        }

        await notificationScheduler?.rescheduleRoutineNotifications(routines: routines, allTasks: allTasks)
    }

    // MARK: - Routine Task Generation

    func generateTasksFromRoutines(for date: Date) async throws {
        try Task.checkCancellation()
        let calendar = Calendar.current

        for routine in routines where routine.shouldRunOn(date: date) {
            // Check if task already exists for this routine on this date
            let existingTask = allTasks.first {
                $0.routineId == routine.id && calendar.isDate($0.date, inSameDayAs: date)
            }

            if existingTask == nil {
                let task = routine.createTask(for: date)
                try await createTask(task)
            }
        }
    }

    // MARK: - Private Helpers

    private func updateRoutineTasksForToday(routine: DailyRoutine) async {
        let calendar = Calendar.current

        // Find today's task from this routine
        if let existingTask = allTasks.first(where: {
            $0.routineId == routine.id && calendar.isDate($0.date, inSameDayAs: selectedDate)
        }) {
            // Update the task with new routine values (but keep completion status)
            var updatedTask = existingTask
            updatedTask.title = routine.title
            updatedTask.startTime = routine.startTime
            updatedTask.endTime = routine.endTime
            updatedTask.category = routine.category
            updatedTask.notes = routine.notes

            do { try await updateTask(updatedTask) }
            catch { print("[DayPlannerService] Failed to sync routine task '\(routine.title)': \(error)") }
        }
    }

    // MARK: - Streak (for XP multiplier)

    private func maxCurrentStreak() -> Int {
        routines
            .filter(\.isEnabled)
            .map { StreakCalculator.currentStreak(for: $0, tasks: allTasks) }
            .max() ?? 0
    }

    // MARK: - Cleanup

    func cleanupOldTasks(olderThan days: Int = 30) async throws {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        try await taskRepository.deleteOlderThan(cutoffDate)
        allTasks.removeAll { $0.date < cutoffDate }
    }
}
