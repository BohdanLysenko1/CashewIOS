import Foundation
import Observation

@Observable
@MainActor
final class EventFormViewModel {

    // MARK: - Form Fields

    var title: String = ""
    var date: Date = Date()
    var endDate: Date?
    var hasEndDate: Bool = false
    var location: String = ""
    var locationLatitude: Double?
    var locationLongitude: Double?
    var address: String = ""
    var notes: String = ""
    var category: EventCategory = .general
    var isAllDay: Bool = false
    var priority: EventPriority = .medium

    // Reminders
    var reminders: [Reminder] = []

    // Recurrence
    var isRecurring: Bool = false
    var recurrenceFrequency: RecurrenceFrequency = .weekly
    var recurrenceInterval: Int = 1
    var recurrenceEndDate: Date?
    var hasRecurrenceEndDate: Bool = false
    var selectedDaysOfWeek: Set<DayOfWeek> = []

    // Links & Cost
    var urlString: String = ""
    var costString: String = ""
    var currency: String = "USD"
    var customCategoryName: String = ""

    // Attachments
    var attachments: [Attachment] = []

    // MARK: - State

    private(set) var isSaving = false
    var error: String?
    private(set) var didSave = false

    // MARK: - Validation

    var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidCustomCategory = category != .custom || customCategoryError == nil
        let hasValidCost = costError == nil

        return !trimmedTitle.isEmpty &&
            (!hasEndDate || (endDate ?? date) >= date) &&
            hasValidCustomCategory &&
            hasValidCost
    }

    var titleError: String? {
        if title.isEmpty { return nil }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Title cannot be empty"
        }
        return nil
    }

    var dateError: String? {
        guard hasEndDate, let endDate else { return nil }
        if endDate < date {
            return "End time must be after start time"
        }
        return nil
    }

    var customCategoryError: String? {
        guard category == .custom else { return nil }
        if customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Custom category name is required"
        }
        return nil
    }

    var costError: String? {
        let trimmed = costString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return parseCost(trimmed) == nil ? "Enter a valid cost" : nil
    }

    // MARK: - Dependencies

    private let eventService: EventServiceProtocol
    private let existingEvent: Event?

    var isEditing: Bool { existingEvent != nil }

    // MARK: - Init

    init(eventService: EventServiceProtocol, event: Event? = nil) {
        self.eventService = eventService
        self.existingEvent = event

        if let event {
            self.title = event.title
            self.date = event.date
            self.endDate = event.endDate
            self.hasEndDate = event.endDate != nil
            self.location = event.location
            self.locationLatitude = event.locationLatitude
            self.locationLongitude = event.locationLongitude
            self.address = event.address
            self.notes = event.notes
            self.category = event.category
            self.isAllDay = event.isAllDay
            self.priority = event.priority
            self.reminders = event.reminders
            self.attachments = event.attachments
            self.currency = event.currency

            self.customCategoryName = event.customCategoryName ?? ""

            if let url = event.url {
                self.urlString = url.absoluteString
            }
            if let cost = event.cost {
                self.costString = "\(cost)"
            }

            if let rule = event.recurrenceRule {
                self.isRecurring = true
                self.recurrenceFrequency = rule.frequency
                self.recurrenceInterval = rule.interval
                self.recurrenceEndDate = rule.endDate
                self.hasRecurrenceEndDate = rule.endDate != nil
                self.selectedDaysOfWeek = rule.daysOfWeek ?? []
            }
        }
    }

    // MARK: - Actions

    func save() async {
        guard isValid else { return }

        isSaving = true
        error = nil

        let recurrenceRule: RecurrenceRule? = isRecurring ? RecurrenceRule(
            frequency: recurrenceFrequency,
            interval: recurrenceInterval,
            endDate: hasRecurrenceEndDate ? recurrenceEndDate : nil,
            daysOfWeek: recurrenceFrequency == .weekly && !selectedDaysOfWeek.isEmpty ? selectedDaysOfWeek : nil
        ) : nil

        let url = normalizeURL(urlString)
        let cost = parseCost(costString)
        let resolvedCustomName: String? = category == .custom && !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        if let name = resolvedCustomName {
            CustomCategoryStore.shared.addEventCategory(name)
        }

        do {
            if let existingEvent {
                let updatedEvent = Event(
                    id: existingEvent.id,
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
                    createdAt: existingEvent.createdAt,
                    updatedAt: Date(),
                    priority: priority,
                    reminders: reminders,
                    recurrenceRule: recurrenceRule,
                    attachments: attachments,
                    url: url,
                    cost: cost,
                    currency: currency,
                    tripId: existingEvent.tripId,
                    ownerId: existingEvent.ownerId,
                    ownerName: existingEvent.ownerName
                )
                try await eventService.updateEvent(updatedEvent)
            } else {
                let newEvent = Event(
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
                    url: url,
                    cost: cost,
                    currency: currency
                )
                try await eventService.createEvent(newEvent)
            }
            didSave = true
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func clearError() {
        error = nil
    }

    // MARK: - Reminder Helpers

    func addReminder(_ interval: ReminderInterval) {
        guard !reminders.contains(where: { $0.interval == interval }) else { return }
        reminders.append(Reminder(interval: interval))
    }

    func removeReminder(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
    }

    // MARK: - Attachment Helpers

    @discardableResult
    func addLinkAttachment(name: String, urlString: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let url = normalizeURL(urlString) else { return false }
        let attachment = Attachment(name: trimmedName, type: .link, url: url)
        attachments.append(attachment)
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

    private func normalizeURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(string: "https://\(trimmed)")
    }

    private func parseCost(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed.replacingOccurrences(of: ",", with: "."))
    }
}
