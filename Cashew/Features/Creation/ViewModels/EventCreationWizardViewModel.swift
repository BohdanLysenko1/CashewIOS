import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class EventCreationWizardViewModel {

    // MARK: - Step

    static let totalSteps = 4

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

    // MARK: - Step 2: Details

    var category: EventCategory = .general
    var priority: EventPriority = .medium
    var costString: String = ""
    var currency: String = "USD"

    static let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "INR", "MXN", "BRL"]

    // MARK: - Step 3: Notes & Photos

    var notes: String = ""
    var photoAttachments: [Attachment] = []

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
            return !title.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            return !hasEndDate || endDate >= date
        default:
            return true
        }
    }

    var stepTitle: String {
        switch currentStep {
        case 0: return "Name Your Event"
        case 1: return "When Is It?"
        case 2: return "Event Details"
        case 3: return "Notes & Photos"
        default: return ""
        }
    }

    var stepSubtitle: String {
        switch currentStep {
        case 0: return "Give your event a title and location"
        case 1: return "Set the date and time"
        case 2: return "Category, priority, and cost"
        case 3: return "Optional — any extra details"
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

    // MARK: - Save

    func save() async {
        isSaving = true
        error = nil

        let cost = Decimal(string: costString.replacingOccurrences(of: ",", with: "."))
        let eventId = UUID()

        let event = Event(
            id: eventId,
            title: title.trimmingCharacters(in: .whitespaces),
            date: date,
            endDate: hasEndDate ? endDate : nil,
            location: location.trimmingCharacters(in: .whitespaces),
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            address: address.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            isAllDay: isAllDay,
            priority: priority,
            attachments: photoAttachments,
            cost: cost,
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
}
