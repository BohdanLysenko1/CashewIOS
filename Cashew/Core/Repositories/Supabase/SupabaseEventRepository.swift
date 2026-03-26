import Foundation
import Supabase

// MARK: - Event DTO

struct EventDTO: Codable {
    let id: UUID
    let ownerId: UUID
    let ownerName: String?
    let title: String
    let date: Date
    let endDate: Date?
    let location: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    let address: String?
    let notes: String?
    let category: String
    let isAllDay: Bool
    let priority: String
    let url: String?
    let cost: Double?
    let currency: String?
    let customCategoryName: String?
    let tripId: UUID?
    let reminders: [Reminder]
    let recurrenceRule: RecurrenceRule?
    let attachments: [Attachment]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId    = "owner_id"
        case ownerName  = "owner_name"
        case title, date, notes, category, priority, url, cost, currency
        case endDate              = "end_date"
        case location
        case locationLatitude     = "location_latitude"
        case locationLongitude    = "location_longitude"
        case address
        case isAllDay             = "is_all_day"
        case customCategoryName   = "custom_category_name"
        case tripId               = "trip_id"
        case reminders
        case recurrenceRule       = "recurrence_rule"
        case attachments
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
    }

    func toEvent() -> Event {
        Event(
            id: id,
            title: title,
            date: date,
            endDate: endDate,
            location: location ?? "",
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            address: address ?? "",
            notes: notes ?? "",
            category: EventCategory(rawValue: category) ?? .general,
            customCategoryName: customCategoryName,
            isAllDay: isAllDay,
            priority: EventPriority(rawValue: priority) ?? .medium,
            reminders: reminders,
            recurrenceRule: recurrenceRule,
            attachments: attachments,
            url: url.flatMap { URL(string: $0) },
            cost: cost.map { Decimal($0) },
            currency: currency ?? "USD",
            tripId: tripId,
            ownerId: ownerId,
            ownerName: ownerName
        )
    }
}

// MARK: - Event Insert/Update payload

private struct EventPayload: Encodable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let date: Date
    let endDate: Date?
    let location: String
    let locationLatitude: Double?
    let locationLongitude: Double?
    let address: String
    let notes: String
    let category: String
    let isAllDay: Bool
    let priority: String
    let url: String?
    let cost: Double?
    let currency: String
    let customCategoryName: String?
    let tripId: UUID?
    let reminders: [Reminder]
    let recurrenceRule: RecurrenceRule?
    let attachments: [Attachment]

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId            = "owner_id"
        case title, date, notes, category, priority, url, cost, currency, location, address, reminders, attachments
        case endDate            = "end_date"
        case locationLatitude   = "location_latitude"
        case locationLongitude  = "location_longitude"
        case isAllDay           = "is_all_day"
        case customCategoryName = "custom_category_name"
        case tripId             = "trip_id"
        case recurrenceRule     = "recurrence_rule"
    }

    init(event: Event, ownerId: UUID) {
        self.id = event.id
        self.ownerId = ownerId
        self.title = event.title
        self.date = event.date
        self.endDate = event.endDate
        self.location = event.location
        self.locationLatitude = event.locationLatitude
        self.locationLongitude = event.locationLongitude
        self.address = event.address
        self.notes = event.notes
        self.category = event.category.rawValue
        self.isAllDay = event.isAllDay
        self.priority = event.priority.rawValue
        self.url = event.url?.absoluteString
        self.cost = event.cost.map { Double(truncating: $0 as NSNumber) }
        self.currency = event.currency
        self.customCategoryName = event.customCategoryName
        self.tripId = event.tripId
        self.reminders = event.reminders
        self.recurrenceRule = event.recurrenceRule
        self.attachments = event.attachments
    }
}

// MARK: - Repository

@MainActor
final class SupabaseEventRepository: EventRepositoryProtocol {

    private let client = SupabaseManager.client

    init() {}

    func fetchAll() async throws -> [Event] {
        let dtos: [EventDTO] = try await client
            .from(SupabaseSchema.Table.events)
            .select(SupabaseSchema.Select.eventWithOwner)
            .execute()
            .value
        return dtos.map { $0.toEvent() }
    }

    func fetch(by id: UUID) async throws -> Event {
        let dto: EventDTO = try await client
            .from(SupabaseSchema.Table.events)
            .select(SupabaseSchema.Select.eventWithOwner)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return dto.toEvent()
    }

    @discardableResult
    func save(_ event: Event) async throws -> Event {
        let ownerId: UUID
        if let existing = event.ownerId {
            ownerId = existing
        } else {
            let session = try await client.auth.session
            ownerId = session.user.id
        }
        let payload = EventPayload(event: event, ownerId: ownerId)
        let dto: EventDTO = try await client
            .from(SupabaseSchema.Table.events)
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value
        return dto.toEvent()
    }

    func delete(by id: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.events)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteAll(userId: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.events)
            .delete()
            .eq("owner_id", value: userId.uuidString)
            .execute()
    }
}
