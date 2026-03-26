import Foundation
import Observation

@Observable
@MainActor
final class TaskCreationWizardViewModel {

    static let totalSteps = 5

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

    // MARK: - State
    private(set) var isSaving = false
    var error: String?
    private(set) var savedTaskId: UUID?

    // MARK: - Dependencies
    private let service: DayPlannerServiceProtocol
    private let tripService: TripServiceProtocol
    private let eventService: EventServiceProtocol

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
            return !hasTime || !hasEndTime || endTime >= startTime
        case 2:
            if category != .custom { return true }
            return !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    var stepTitle: String {
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
        guard currentStep < Self.totalSteps - 1 else { return }
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

        let resolvedCustomName: String? = category == .custom && !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        if let name = resolvedCustomName {
            CustomCategoryStore.shared.addTaskCategory(name)
        }

        let taskId = UUID()
        let task = DailyTask(
            id: taskId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            startTime: hasTime ? startTime : nil,
            endTime: hasTime && hasEndTime ? endTime : nil,
            isCompleted: false,
            category: category,
            customCategoryName: resolvedCustomName,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            routineId: nil,
            tripId: selectedTripId,
            eventId: selectedEventId,
            subtasks: subtasks
        )

        do {
            try await service.createTask(task)
            savedTaskId = taskId
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func clearError() {
        error = nil
    }
}
