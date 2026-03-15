import Foundation
import Observation

@Observable
@MainActor
final class TripFormViewModel {

    // MARK: - Form Fields

    var name: String = ""
    var destination: String = ""
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week default
    var notes: String = ""
    var photoAttachments: [Attachment] = []

    // MARK: - State

    private(set) var isSaving = false
    var error: String?
    private(set) var didSave = false

    // MARK: - Validation

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate >= startDate
    }

    var nameError: String? {
        if name.isEmpty { return nil }
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Name cannot be empty"
        }
        return nil
    }

    var destinationError: String? {
        if destination.isEmpty { return nil }
        if destination.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Destination cannot be empty"
        }
        return nil
    }

    var dateError: String? {
        if endDate < startDate {
            return "End date must be after start date"
        }
        return nil
    }

    // MARK: - Dependencies

    private let tripService: TripServiceProtocol
    private let existingTrip: Trip?

    var isEditing: Bool { existingTrip != nil }

    // MARK: - Init

    init(tripService: TripServiceProtocol, trip: Trip? = nil) {
        self.tripService = tripService
        self.existingTrip = trip

        if let trip {
            self.name = trip.name
            self.destination = trip.destination
            self.destinationLatitude = trip.destinationLatitude
            self.destinationLongitude = trip.destinationLongitude
            self.startDate = trip.startDate
            self.endDate = trip.endDate
            self.notes = trip.notes
            self.photoAttachments = trip.attachments.filter { $0.type == .image }
        }
    }

    // MARK: - Actions

    func save() async {
        guard isValid else { return }

        isSaving = true
        error = nil

        do {
            if let existingTrip {
                // Merge: keep non-image attachments from existing trip, replace image attachments with current
                let nonPhotoAttachments = existingTrip.attachments.filter { $0.type != .image }
                let updatedTrip = Trip(
                    id: existingTrip.id,
                    ownerId: existingTrip.ownerId,
                    ownerName: existingTrip.ownerName,
                    name: name.trimmingCharacters(in: .whitespaces),
                    destination: destination.trimmingCharacters(in: .whitespaces),
                    destinationLatitude: destinationLatitude,
                    destinationLongitude: destinationLongitude,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    coverImageURL: existingTrip.coverImageURL,
                    status: existingTrip.status,
                    createdAt: existingTrip.createdAt,
                    updatedAt: Date(),
                    budget: existingTrip.budget,
                    currency: existingTrip.currency,
                    expenses: existingTrip.expenses,
                    activities: existingTrip.activities,
                    packingItems: existingTrip.packingItems,
                    checklistItems: existingTrip.checklistItems,
                    attachments: nonPhotoAttachments + photoAttachments,
                    accommodationName: existingTrip.accommodationName,
                    accommodationAddress: existingTrip.accommodationAddress,
                    accommodationCheckIn: existingTrip.accommodationCheckIn,
                    accommodationCheckOut: existingTrip.accommodationCheckOut,
                    accommodationConfirmation: existingTrip.accommodationConfirmation,
                    transportationType: existingTrip.transportationType,
                    transportationDetails: existingTrip.transportationDetails,
                    transportationConfirmation: existingTrip.transportationConfirmation
                )
                try await tripService.updateTrip(updatedTrip)
            } else {
                let newTrip = Trip(
                    name: name.trimmingCharacters(in: .whitespaces),
                    destination: destination.trimmingCharacters(in: .whitespaces),
                    destinationLatitude: destinationLatitude,
                    destinationLongitude: destinationLongitude,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    attachments: photoAttachments
                )
                try await tripService.createTrip(newTrip)
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
}
