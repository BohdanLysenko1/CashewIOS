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
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!hasEndDate || (endDate ?? date) >= date)
    }

    var titleError: String? {
        if title.isEmpty { return nil }
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
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

        let url = URL(string: urlString)
        let cost = Decimal(string: costString)
        let resolvedCustomName: String? = category == .custom && !customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty
            ? customCategoryName.trimmingCharacters(in: .whitespaces)
            : nil

        if let name = resolvedCustomName {
            CustomCategoryStore.shared.addEventCategory(name)
        }

        do {
            if let existingEvent {
                let updatedEvent = Event(
                    id: existingEvent.id,
                    title: title.trimmingCharacters(in: .whitespaces),
                    date: date,
                    endDate: hasEndDate ? endDate : nil,
                    location: location.trimmingCharacters(in: .whitespaces),
                    locationLatitude: locationLatitude,
                    locationLongitude: locationLongitude,
                    address: address.trimmingCharacters(in: .whitespaces),
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
                    title: title.trimmingCharacters(in: .whitespaces),
                    date: date,
                    endDate: hasEndDate ? endDate : nil,
                    location: location.trimmingCharacters(in: .whitespaces),
                    locationLatitude: locationLatitude,
                    locationLongitude: locationLongitude,
                    address: address.trimmingCharacters(in: .whitespaces),
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

    func addLinkAttachment(name: String, urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let attachment = Attachment(name: name, type: .link, url: url)
        attachments.append(attachment)
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
}
