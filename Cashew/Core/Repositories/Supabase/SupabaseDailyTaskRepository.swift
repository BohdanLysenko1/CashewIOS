import Foundation
import Supabase

// MARK: - DailyTask DTO

struct DailyTaskDTO: Codable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let date: Date
    let startTime: Date?
    let endTime: Date?
    let isCompleted: Bool
    let category: String
    let customCategoryName: String?
    let notes: String?
    let routineId: UUID?
    let tripId: UUID?
    let eventId: UUID?
    let subtasks: [Subtask]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId            = "owner_id"
        case title, date, notes, category, subtasks
        case startTime          = "start_time"
        case endTime            = "end_time"
        case isCompleted        = "is_completed"
        case customCategoryName = "custom_category_name"
        case routineId          = "routine_id"
        case tripId             = "trip_id"
        case eventId            = "event_id"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }

    func toTask() -> DailyTask {
        DailyTask(
            id: id,
            title: title,
            date: date,
            startTime: startTime,
            endTime: endTime,
            isCompleted: isCompleted,
            category: TaskCategory(rawValue: category) ?? .personal,
            customCategoryName: customCategoryName,
            notes: notes ?? "",
            routineId: routineId,
            tripId: tripId,
            eventId: eventId,
            subtasks: subtasks,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - DailyTask Insert/Update Payload

private struct DailyTaskPayload: Encodable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let date: Date
    let startTime: Date?
    let endTime: Date?
    let isCompleted: Bool
    let category: String
    let customCategoryName: String?
    let notes: String
    let routineId: UUID?
    let tripId: UUID?
    let eventId: UUID?
    let subtasks: [Subtask]

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId            = "owner_id"
        case title, date, notes, category, subtasks
        case startTime          = "start_time"
        case endTime            = "end_time"
        case isCompleted        = "is_completed"
        case customCategoryName = "custom_category_name"
        case routineId          = "routine_id"
        case tripId             = "trip_id"
        case eventId            = "event_id"
    }

    init(task: DailyTask, ownerId: UUID) {
        self.id = task.id
        self.ownerId = ownerId
        self.title = task.title
        self.date = task.date
        self.startTime = task.startTime
        self.endTime = task.endTime
        self.isCompleted = task.isCompleted
        self.category = task.category.rawValue
        self.customCategoryName = task.customCategoryName
        self.notes = task.notes
        self.routineId = task.routineId
        self.tripId = task.tripId
        self.eventId = task.eventId
        self.subtasks = task.subtasks
    }
}

// MARK: - Repository

@MainActor
final class SupabaseDailyTaskRepository: DailyTaskRepositoryProtocol, @unchecked Sendable {

    private let client = SupabaseManager.client

    init() {}

    func fetchAll() async throws -> [DailyTask] {
        let dtos: [DailyTaskDTO] = try await client
            .from(SupabaseSchema.Table.dailyTasks)
            .select()
            .execute()
            .value
        return dtos.map { $0.toTask() }
    }

    func fetchTasks(for date: Date) async throws -> [DailyTask] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let dtos: [DailyTaskDTO] = try await client
            .from(SupabaseSchema.Table.dailyTasks)
            .select()
            .gte("date", value: startOfDay.ISO8601Format())
            .lt("date", value: endOfDay.ISO8601Format())
            .execute()
            .value
        return dtos.map { $0.toTask() }
    }

    @discardableResult
    func save(_ task: DailyTask) async throws -> DailyTask {
        let session = try await client.auth.session
        let payload = DailyTaskPayload(task: task, ownerId: session.user.id)
        let dto: DailyTaskDTO = try await client
            .from(SupabaseSchema.Table.dailyTasks)
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value
        return dto.toTask()
    }

    func delete(by id: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.dailyTasks)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteOlderThan(_ date: Date) async throws {
        let startOfDay = Calendar.current.startOfDay(for: date)
        try await client
            .from(SupabaseSchema.Table.dailyTasks)
            .delete()
            .lt("date", value: startOfDay.ISO8601Format())
            .execute()
    }

    func deleteAll(userId: UUID) async throws {
        try await client
            .from(SupabaseSchema.Table.dailyTasks)
            .delete()
            .eq("owner_id", value: userId.uuidString)
            .execute()
    }
}
