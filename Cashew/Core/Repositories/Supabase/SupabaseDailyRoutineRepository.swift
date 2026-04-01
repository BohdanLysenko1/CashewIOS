import Foundation
import Supabase

// MARK: - DailyRoutine DTO

struct DailyRoutineDTO: Codable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let startTime: Date?
    let endTime: Date?
    let category: String
    let repeatPattern: String
    let selectedDays: [Int]
    let isEnabled: Bool
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId        = "owner_id"
        case title, notes, category
        case startTime      = "start_time"
        case endTime        = "end_time"
        case repeatPattern  = "repeat_pattern"
        case selectedDays   = "selected_days"
        case isEnabled      = "is_enabled"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }

    func toRoutine() -> DailyRoutine {
        let days = Set(selectedDays.compactMap { DayOfWeek(rawValue: $0) })
        return DailyRoutine(
            id: id,
            title: title,
            startTime: startTime,
            endTime: endTime,
            category: TaskCategory(rawValue: category) ?? .personal,
            repeatPattern: RepeatPattern(rawValue: repeatPattern) ?? .daily,
            selectedDays: days,
            isEnabled: isEnabled,
            notes: notes ?? "",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - DailyRoutine Insert/Update Payload

private struct DailyRoutinePayload: Encodable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let startTime: Date?
    let endTime: Date?
    let category: String
    let repeatPattern: String
    let selectedDays: [Int]
    let isEnabled: Bool
    let notes: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId        = "owner_id"
        case title, notes, category
        case startTime      = "start_time"
        case endTime        = "end_time"
        case repeatPattern  = "repeat_pattern"
        case selectedDays   = "selected_days"
        case isEnabled      = "is_enabled"
    }

    init(routine: DailyRoutine, ownerId: UUID) {
        self.id = routine.id
        self.ownerId = ownerId
        self.title = routine.title
        self.startTime = routine.startTime
        self.endTime = routine.endTime
        self.category = routine.category.rawValue
        self.repeatPattern = routine.repeatPattern.rawValue
        self.selectedDays = routine.selectedDays.map { $0.rawValue }.sorted()
        self.isEnabled = routine.isEnabled
        self.notes = routine.notes
    }
}

// MARK: - Repository

@MainActor
final class SupabaseDailyRoutineRepository: DailyRoutineRepositoryProtocol, @unchecked Sendable {

    private let client = SupabaseManager.client

    init() {}

    func fetchAll() async throws -> [DailyRoutine] {
        let dtos: [DailyRoutineDTO] = try await client
            .from(SupabaseSchema.Table.dailyRoutines)
            .select()
            .execute()
            .value
        return dtos.map { $0.toRoutine() }
    }

    func fetch(by id: UUID) async throws -> DailyRoutine {
        let dto: DailyRoutineDTO = try await client
            .from(SupabaseSchema.Table.dailyRoutines)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return dto.toRoutine()
    }

    @discardableResult
    func save(_ routine: DailyRoutine) async throws -> DailyRoutine {
        let session = try await client.auth.session
        let payload = DailyRoutinePayload(routine: routine, ownerId: session.user.id)
        let dto: DailyRoutineDTO = try await client
            .from(SupabaseSchema.Table.dailyRoutines)
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value
        return dto.toRoutine()
    }

    func delete(by id: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.dailyRoutines)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteAll(userId: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.dailyRoutines)
            .delete()
            .eq("owner_id", value: userId.uuidString)
            .execute()
    }
}
