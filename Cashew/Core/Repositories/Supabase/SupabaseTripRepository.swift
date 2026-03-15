import Foundation
import Supabase

// MARK: - Trip DTO (Supabase row ↔ Trip model)

struct TripDTO: Codable {
    let id: UUID
    let ownerId: UUID
    let ownerName: String?   // joined from users table
    let name: String
    let destination: String
    let destinationLatitude: Double?
    let destinationLongitude: Double?
    let startDate: Date
    let endDate: Date
    let notes: String?
    let coverImageUrl: String?
    let status: String
    let budget: Double?
    let currency: String
    let accommodationName: String?
    let accommodationAddress: String?
    let accommodationCheckIn: Date?
    let accommodationCheckOut: Date?
    let accommodationConfirmation: String?
    let transportationType: String?
    let transportationDetails: String?
    let transportationConfirmation: String?
    let expenses: [Expense]
    let activities: [Activity]
    let packingItems: [PackingItem]
    let checklistItems: [ChecklistItem]
    let attachments: [Attachment]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId              = "owner_id"
        case ownerName            = "owner_name"
        case name, destination, notes, status, budget, currency
        case destinationLatitude  = "destination_latitude"
        case destinationLongitude = "destination_longitude"
        case startDate            = "start_date"
        case endDate              = "end_date"
        case coverImageUrl        = "cover_image_url"
        case accommodationName    = "accommodation_name"
        case accommodationAddress = "accommodation_address"
        case accommodationCheckIn = "accommodation_check_in"
        case accommodationCheckOut = "accommodation_check_out"
        case accommodationConfirmation = "accommodation_confirmation"
        case transportationType   = "transportation_type"
        case transportationDetails = "transportation_details"
        case transportationConfirmation = "transportation_confirmation"
        case expenses, activities
        case packingItems   = "packing_items"
        case checklistItems = "checklist_items"
        case attachments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toTrip() -> Trip {
        Trip(
            id: id,
            ownerId: ownerId,
            ownerName: ownerName,
            name: name,
            destination: destination,
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
            startDate: startDate,
            endDate: endDate,
            notes: notes ?? "",
            coverImageURL: coverImageUrl.flatMap { URL(string: $0) },
            status: TripStatus(rawValue: status) ?? .planning,
            budget: budget.map { Decimal($0) },
            currency: currency,
            expenses: expenses,
            activities: activities,
            packingItems: packingItems,
            checklistItems: checklistItems,
            attachments: attachments,
            accommodationName: accommodationName ?? "",
            accommodationAddress: accommodationAddress ?? "",
            accommodationCheckIn: accommodationCheckIn,
            accommodationCheckOut: accommodationCheckOut,
            accommodationConfirmation: accommodationConfirmation ?? "",
            transportationType: transportationType ?? "",
            transportationDetails: transportationDetails ?? "",
            transportationConfirmation: transportationConfirmation ?? ""
        )
    }
}

// MARK: - Trip → Insert/Update payload

private struct TripPayload: Encodable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let destination: String
    let destinationLatitude: Double?
    let destinationLongitude: Double?
    let startDate: Date
    let endDate: Date
    let notes: String
    let coverImageUrl: String?
    let status: String
    let budget: Double?
    let currency: String
    let accommodationName: String
    let accommodationAddress: String
    let accommodationCheckIn: Date?
    let accommodationCheckOut: Date?
    let accommodationConfirmation: String
    let transportationType: String
    let transportationDetails: String
    let transportationConfirmation: String
    let expenses: [Expense]
    let activities: [Activity]
    let packingItems: [PackingItem]
    let checklistItems: [ChecklistItem]
    let attachments: [Attachment]

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId              = "owner_id"
        case name, destination, notes, status, budget, currency
        case destinationLatitude  = "destination_latitude"
        case destinationLongitude = "destination_longitude"
        case startDate            = "start_date"
        case endDate              = "end_date"
        case coverImageUrl        = "cover_image_url"
        case accommodationName    = "accommodation_name"
        case accommodationAddress = "accommodation_address"
        case accommodationCheckIn = "accommodation_check_in"
        case accommodationCheckOut = "accommodation_check_out"
        case accommodationConfirmation = "accommodation_confirmation"
        case transportationType   = "transportation_type"
        case transportationDetails = "transportation_details"
        case transportationConfirmation = "transportation_confirmation"
        case expenses, activities
        case packingItems   = "packing_items"
        case checklistItems = "checklist_items"
        case attachments
    }

    init(trip: Trip, ownerId: UUID) {
        self.id = trip.id
        self.ownerId = ownerId
        self.name = trip.name
        self.destination = trip.destination
        self.destinationLatitude = trip.destinationLatitude
        self.destinationLongitude = trip.destinationLongitude
        self.startDate = trip.startDate
        self.endDate = trip.endDate
        self.notes = trip.notes
        self.coverImageUrl = trip.coverImageURL?.absoluteString
        self.status = trip.status.rawValue
        self.budget = trip.budget.map { Double(truncating: $0 as NSNumber) }
        self.currency = trip.currency
        self.accommodationName = trip.accommodationName
        self.accommodationAddress = trip.accommodationAddress
        self.accommodationCheckIn = trip.accommodationCheckIn
        self.accommodationCheckOut = trip.accommodationCheckOut
        self.accommodationConfirmation = trip.accommodationConfirmation
        self.transportationType = trip.transportationType
        self.transportationDetails = trip.transportationDetails
        self.transportationConfirmation = trip.transportationConfirmation
        self.expenses = trip.expenses
        self.activities = trip.activities
        self.packingItems = trip.packingItems
        self.checklistItems = trip.checklistItems
        self.attachments = trip.attachments
    }
}

// MARK: - Repository

@MainActor
final class SupabaseTripRepository: TripRepositoryProtocol {

    private let client = SupabaseManager.client

    init() {}

    // MARK: - Fetch All

    func fetchAll() async throws -> [Trip] {
        // Fetch owned trips + shared trips in one query via LEFT JOIN
        let dtos: [TripDTO] = try await client
            .from(SupabaseSchema.Table.trips)
            .select(SupabaseSchema.Select.tripWithOwner)
            .execute()
            .value
        return dtos.map { $0.toTrip() }
    }

    // MARK: - Fetch by ID

    func fetch(by id: UUID) async throws -> Trip {
        let dto: TripDTO = try await client
            .from(SupabaseSchema.Table.trips)
            .select(SupabaseSchema.Select.tripWithOwner)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return dto.toTrip()
    }

    // MARK: - Save (insert or update)

    @discardableResult
    func save(_ trip: Trip) async throws -> Trip {
        let ownerId: UUID
        if let existing = trip.ownerId {
            ownerId = existing
        } else {
            let session = try await client.auth.session
            ownerId = session.user.id
        }
        let payload = TripPayload(trip: trip, ownerId: ownerId)
        let dto: TripDTO = try await client
            .from(SupabaseSchema.Table.trips)
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value
        return dto.toTrip()
    }

    // MARK: - Delete

    func delete(by id: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.trips)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

