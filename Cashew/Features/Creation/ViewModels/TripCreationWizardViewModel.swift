import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class TripCreationWizardViewModel {

    // MARK: - Step

    static let totalSteps = 6

    private(set) var currentStep = 0

    // MARK: - Step 0: Basics

    var name: String = ""
    var destination: String = ""
    var destinationLatitude: Double?
    var destinationLongitude: Double?

    // MARK: - Step 1: Dates

    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60)

    // MARK: - Step 2: Budget

    var budgetString: String = ""
    var currency: String = "USD"

    static let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "INR", "MXN", "BRL"]

    // MARK: - Step 3: Packing

    var packingItems: [PackingItem] = []
    var newPackingItemName: String = ""
    var newPackingCategory: PackingCategory = .other

    static let packingSuggestions: [(name: String, category: PackingCategory)] = [
        ("Passport", .documents),
        ("Phone Charger", .electronics),
        ("Toothbrush", .toiletries),
        ("T-Shirts", .clothing),
        ("Sunscreen", .toiletries),
        ("Headphones", .electronics),
        ("Medications", .medicine),
        ("Snacks", .snacks),
        ("Power Bank", .electronics),
        ("Sunglasses", .accessories)
    ]

    // MARK: - Step 4: Checklist

    var checklistItems: [ChecklistItem] = []
    var newChecklistTitle: String = ""
    var newChecklistPriority: ChecklistPriority = .medium

    static let checklistSuggestions: [(title: String, priority: ChecklistPriority)] = [
        ("Book accommodation", .high),
        ("Check passport expiry", .urgent),
        ("Buy travel insurance", .high),
        ("Notify bank of travel", .medium),
        ("Download offline maps", .medium),
        ("Arrange airport transfer", .medium),
        ("Pack medications", .high),
        ("Confirm flight details", .urgent)
    ]

    // MARK: - Step 5: Notes & Photos

    var notes: String = ""
    var photoAttachments: [Attachment] = []

    // MARK: - State

    private(set) var isSaving = false
    var error: String?
    private(set) var savedTripId: UUID?

    // MARK: - Dependencies

    private let tripService: TripServiceProtocol

    init(tripService: TripServiceProtocol) {
        self.tripService = tripService
    }

    // MARK: - Step Validation

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !destination.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            return endDate >= startDate
        default:
            return true
        }
    }

    var stepTitle: String {
        switch currentStep {
        case 0: return "Name Your Trip"
        case 1: return "When Are You Going?"
        case 2: return "Set a Budget"
        case 3: return "Packing List"
        case 4: return "Pre-Trip Checklist"
        case 5: return "Notes & Photos"
        default: return ""
        }
    }

    var stepSubtitle: String {
        switch currentStep {
        case 0: return "Give your trip a name and destination"
        case 1: return "Choose your travel dates"
        case 2: return "Optional — track your spending"
        case 3: return "Optional — add items to pack"
        case 4: return "Optional — things to do before you leave"
        case 5: return "Optional — any extra details"
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

    // MARK: - Packing Helpers

    func addPackingItem() {
        let trimmed = newPackingItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        packingItems.append(PackingItem(name: trimmed, category: newPackingCategory))
        newPackingItemName = ""
        newPackingCategory = .other
    }

    func removePackingItems(at offsets: IndexSet) {
        packingItems.remove(atOffsets: offsets)
    }

    func toggleSuggestedPackingItem(name: String, category: PackingCategory) {
        if let idx = packingItems.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
            packingItems.remove(at: idx)
        } else {
            packingItems.append(PackingItem(name: name, category: category))
        }
    }

    func isSuggestedPackingItemAdded(_ name: String) -> Bool {
        packingItems.contains { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Checklist Helpers

    func addChecklistItem() {
        let trimmed = newChecklistTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        checklistItems.append(ChecklistItem(title: trimmed, priority: newChecklistPriority))
        newChecklistTitle = ""
        newChecklistPriority = .medium
    }

    func removeChecklistItems(at offsets: IndexSet) {
        checklistItems.remove(atOffsets: offsets)
    }

    func toggleSuggestedChecklistItem(title: String, priority: ChecklistPriority) {
        if let idx = checklistItems.firstIndex(where: { $0.title.lowercased() == title.lowercased() }) {
            checklistItems.remove(at: idx)
        } else {
            checklistItems.append(ChecklistItem(title: title, priority: priority))
        }
    }

    func isSuggestedChecklistItemAdded(_ title: String) -> Bool {
        checklistItems.contains { $0.title.lowercased() == title.lowercased() }
    }

    // MARK: - Save

    func save() async {
        isSaving = true
        error = nil

        let budget = Decimal(string: budgetString.replacingOccurrences(of: ",", with: "."))
        let tripId = UUID()

        let trip = Trip(
            id: tripId,
            name: name.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
            startDate: startDate,
            endDate: endDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            budget: budget,
            currency: currency,
            packingItems: packingItems,
            checklistItems: checklistItems,
            attachments: photoAttachments
        )

        do {
            try await tripService.createTrip(trip)
            savedTripId = tripId
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func clearError() {
        error = nil
    }
}
