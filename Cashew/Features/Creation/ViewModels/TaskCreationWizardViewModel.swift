import Foundation
import Observation

@Observable
@MainActor
final class TaskCreationWizardViewModel {

    static let regularFlowSteps = 5
    static let routineFlowSteps = 4

    private(set) var currentStep = 0

    // MARK: - Step 0: Basics
    var title: String = ""
    var date: Date

    // MARK: - Step 1: Schedule
    var hasTime = false
    var startTime: Date
    var hasEndTime = false
    var endTime: Date

    // MARK: - Step 2: Category & Links
    var category: TaskCategory = .personal
    var customCategoryName: String = ""
    var selectedTripId: UUID?
    var selectedEventId: UUID?

    // MARK: - Step 3: Subtasks
    var subtasks: [Subtask] = []
    var newSubtaskTitle: String = ""

    // MARK: - Step 4: Notes
    var notes: String = ""
    var createAsRoutine = false {
        didSet {
            if createAsRoutine {
                selectedTripId = nil
                selectedEventId = nil
                subtasks.removeAll()
                if category == .custom {
                    category = .personal
                    customCategoryName = ""
                }
            }
            if currentStep >= totalSteps {
                currentStep = max(0, totalSteps - 1)
            }
        }
    }
    var repeatPattern: RepeatPattern = .daily
    var selectedRepeatDays: Set<DayOfWeek> = []

    // MARK: - State
    private(set) var isSaving = false
    var error: String?
    private(set) var savedTaskId: UUID?

    // MARK: - Dependencies
    private let service: DayPlannerServiceProtocol
    private let tripService: TripServiceProtocol
    private let eventService: EventServiceProtocol

    var totalSteps: Int {
        createAsRoutine ? Self.routineFlowSteps : Self.regularFlowSteps
    }

    var availableCategories: [TaskCategory] {
        if createAsRoutine {
            return TaskCategory.allCases.filter { $0 != .custom }
        }
        return TaskCategory.allCases
    }

    init(
        service: DayPlannerServiceProtocol,
        tripService: TripServiceProtocol,
        eventService: EventServiceProtocol,
        defaultDate: Date
    ) {
        self.service = service
        self.tripService = tripService
        self.eventService = eventService
        self.date = defaultDate

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let defaultStart = calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: Date()) ?? Date()
        self.startTime = defaultStart
        self.endTime = defaultStart.addingTimeInterval(3600)
    }

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            let hasValidTimeRange = !hasTime || !hasEndTime || endTime >= startTime
            let hasValidRepeatDays = !createAsRoutine || repeatPattern != .custom || !selectedRepeatDays.isEmpty
            return hasValidTimeRange && hasValidRepeatDays
        case 2:
            if createAsRoutine {
                return true
            }
            if category != .custom { return true }
            return !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    var stepTitle: String {
        if createAsRoutine {
            switch currentStep {
            case 0: return "What routine do you want to build?"
            case 1: return "When should it repeat?"
            case 2: return "Choose a category"
            case 3: return "Final Notes"
            default: return ""
            }
        }

        switch currentStep {
        case 0: return "What needs to get done?"
        case 1: return "When should it happen?"
        case 2: return "Context & Category"
        case 3: return "Break It Down"
        case 4: return "Final Notes"
        default: return ""
        }
    }

    var stepSubtitle: String {
        if createAsRoutine {
            switch currentStep {
            case 0: return "Set a name, date, and enable routine mode"
            case 1: return "Pick repeat days and optional time"
            case 2: return "Classify this routine"
            case 3: return "Optional details before creating"
            default: return ""
            }
        }

        switch currentStep {
        case 0: return "Set the task name and date"
        case 1: return "Optional timing for your schedule"
        case 2: return "Classify and link this task"
        case 3: return "Optional subtasks for clarity"
        case 4: return "Optional details before creating"
        default: return ""
        }
    }

    func goNext() {
        guard currentStep < totalSteps - 1 else { return }
        currentStep += 1
    }

    func goBack() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    func loadLinkedDataIfNeeded() async {
        if tripService.trips.isEmpty {
            do { try await tripService.loadTrips() } catch { print("[TaskCreationWizard] Failed to load trips: \(error)") }
        }
        if eventService.events.isEmpty {
            do { try await eventService.loadEvents() } catch { print("[TaskCreationWizard] Failed to load events: \(error)") }
        }
    }

    func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        subtasks.append(Subtask(title: trimmed))
        newSubtaskTitle = ""
    }

    func removeSubtask(_ subtask: Subtask) {
        subtasks.removeAll { $0.id == subtask.id }
    }

    func save() async {
        guard isCurrentStepValid else { return }
        isSaving = true
        error = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCustomName: String? = {
            guard !createAsRoutine else { return nil }
            guard category == .custom else { return nil }
            let trimmedCustom = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedCustom.isEmpty ? nil : trimmedCustom
        }()

        if let name = resolvedCustomName {
            CustomCategoryStore.shared.addTaskCategory(name)
        }

        do {
            let routineId: UUID?
            let calendar = Calendar.current
            if createAsRoutine {
                let id = UUID()
                let routine = DailyRoutine(
                    id: id,
                    title: trimmedTitle,
                    startTime: hasTime ? startTime : nil,
                    endTime: hasTime && hasEndTime ? endTime : nil,
                    category: category,
                    repeatPattern: repeatPattern,
                    selectedDays: repeatPattern == .custom ? selectedRepeatDays : [],
                    isEnabled: true,
                    notes: trimmedNotes
                )
                try await service.createRoutine(routine)
                routineId = id

                // Remove any task auto-generated for a different day so the routine
                // starts from the date chosen in the wizard.
                let offDateTasks = service.allTasks.filter {
                    $0.routineId == id &&
                    !calendar.isDate($0.date, inSameDayAs: date)
                }
                for task in offDateTasks {
                    try await service.deleteTask(by: task.id)
                }
            } else {
                routineId = nil
            }

            let existingRoutineTask: DailyTask?
            if let routineId {
                existingRoutineTask = service.allTasks.first {
                    $0.routineId == routineId &&
                    calendar.isDate($0.date, inSameDayAs: date)
                }
            } else {
                existingRoutineTask = nil
            }

            if var existingRoutineTask {
                // If a task was auto-generated for this date when creating the routine,
                // update it with the values from the wizard instead of creating a duplicate.
                existingRoutineTask.title = trimmedTitle
                existingRoutineTask.date = date
                existingRoutineTask.startTime = hasTime ? startTime : nil
                existingRoutineTask.endTime = hasTime && hasEndTime ? endTime : nil
                existingRoutineTask.category = category
                existingRoutineTask.customCategoryName = resolvedCustomName
                existingRoutineTask.notes = trimmedNotes
                existingRoutineTask.tripId = selectedTripId
                existingRoutineTask.eventId = selectedEventId
                existingRoutineTask.subtasks = subtasks
                existingRoutineTask.updatedAt = Date()
                try await service.updateTask(existingRoutineTask)
                savedTaskId = existingRoutineTask.id
            } else {
                let taskId = UUID()
                let task = DailyTask(
                    id: taskId,
                    title: trimmedTitle,
                    date: date,
                    startTime: hasTime ? startTime : nil,
                    endTime: hasTime && hasEndTime ? endTime : nil,
                    isCompleted: false,
                    category: category,
                    customCategoryName: resolvedCustomName,
                    notes: trimmedNotes,
                    routineId: routineId,
                    tripId: selectedTripId,
                    eventId: selectedEventId,
                    subtasks: subtasks
                )
                try await service.createTask(task)
                savedTaskId = taskId
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func clearError() {
        error = nil
    }
}
