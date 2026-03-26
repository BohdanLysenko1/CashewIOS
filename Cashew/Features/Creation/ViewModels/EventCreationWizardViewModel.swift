import Foundation
import Observation

@Observable
@MainActor
final class EventCreationWizardViewModel {

    // MARK: - Step

    static let totalSteps = 5
    private(set) var currentStep = 0

    // MARK: - Step 0: Basics

    var title: String = ""
    var location: String = ""
    var locationLatitude: Double?
    var locationLongitude: Double?
    var address: String = ""

    // MARK: - Step 1: Date & Time

    var date: Date = Date()
    var hasEndDate: Bool = false
    var endDate: Date = Date().addingTimeInterval(3600)
    var isAllDay: Bool = false

    // MARK: - Step 2: Planning Details

    var category: EventCategory = .general
    var customCategoryName: String = ""
    var priority: EventPriority = .medium

    var isRecurring: Bool = false
    var recurrenceFrequency: RecurrenceFrequency = .weekly
    var recurrenceInterval: Int = 1
    var recurrenceEndDate: Date?
    var hasRecurrenceEndDate: Bool = false
    var selectedDaysOfWeek: Set<DayOfWeek> = []

    var reminders: [Reminder] = []

    // MARK: - Step 3: Links & Cost

    var attachments: [Attachment] = []
    var urlString: String = ""
    var costString: String = ""
    var currency: String = "USD"

    static let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "INR", "MXN", "BRL"]

    // MARK: - Step 4: Notes & Photos

    var notes: String = ""

    // MARK: - State

    private(set) var isSaving = false
    var error: String?
    private(set) var savedEventId: UUID?

    // MARK: - Dependencies

    private let eventService: EventServiceProtocol

    init(eventService: EventServiceProtocol) {
        self.eventService = eventService
    }

    // MARK: - Step Validation

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return !hasEndDate || endDate >= date
        case 2:
            if category != .custom { return true }
            return !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            return costString.isEmpty || Decimal(string: costString.replacingOccurrences(of: ",", with: ".")) != nil
        default:
            return true
        }
    }

    var stepTitle: String {
        switch currentStep {
        case 0: return "Name Your Event"
        case 1: return "When Is It?"
        case 2: return "Plan Details"
        case 3: return "Links & Budget"
        case 4: return "Notes & Photos"
        default: return ""
        }
    }

    var stepSubtitle: String {
        switch currentStep {
        case 0: return "Give your event a title and location"
        case 1: return "Set the date and time"
        case 2: return "Category, priority, repeats, and reminders"
        case 3: return "Attachments, links, and optional cost"
        case 4: return "Optional details before creating"
        default: return ""
        }
    }

    // MARK: - Navigation

    func goNext() {
        guard currentStep < Self.totalSteps - 1 else { return }
        currentStep += 1
    }

    func goBack() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    // MARK: - Reminders

    func addReminder(_ interval: ReminderInterval) {
        guard !reminders.contains(where: { $0.interval == interval }) else { return }
        reminders.append(Reminder(interval: interval))
    }

    func removeReminder(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
    }

    // MARK: - Attachments

    func addLinkAttachment(name: String, urlString: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let url = normalizeURL(urlString) else { return false }
        attachments.append(Attachment(name: trimmedName, type: .link, url: url))
        return true
    }

    func removeAttachment(_ attachment: Attachment) {
        if attachment.type == .image, let filename = attachment.localPath {
            ImageStore.delete(filename: filename)
        }
        attachments.removeAll { $0.id == attachment.id }
    }

    var photoAttachments: [Attachment] {
        get { attachments.filter { $0.type == .image } }
        set {
            let nonPhotos = attachments.filter { $0.type != .image }
            attachments = nonPhotos + newValue
        }
    }

    // MARK: - Save

    func save() async {
        isSaving = true
        error = nil

        let recurrenceRule: RecurrenceRule? = isRecurring ? RecurrenceRule(
            frequency: recurrenceFrequency,
            interval: recurrenceInterval,
            endDate: hasRecurrenceEndDate ? recurrenceEndDate : nil,
            daysOfWeek: recurrenceFrequency == .weekly && !selectedDaysOfWeek.isEmpty ? selectedDaysOfWeek : nil
        ) : nil

        let parsedURL = normalizeURL(urlString)
        let parsedCost = Decimal(string: costString.replacingOccurrences(of: ",", with: "."))
        let resolvedCustomName: String? = category == .custom && !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        if let name = resolvedCustomName {
            CustomCategoryStore.shared.addEventCategory(name)
        }

        let eventId = UUID()
        let event = Event(
            id: eventId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            endDate: hasEndDate ? endDate : nil,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            customCategoryName: resolvedCustomName,
            isAllDay: isAllDay,
            priority: priority,
            reminders: reminders,
            recurrenceRule: recurrenceRule,
            attachments: attachments,
            url: parsedURL,
            cost: parsedCost,
            currency: currency
        )

        do {
            try await eventService.createEvent(event)
            savedEventId = eventId
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func clearError() {
        error = nil
    }

    private func normalizeURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(string: "https://\(trimmed)")
    }
}
