import Foundation

struct DailyTask: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var isCompleted: Bool
    var category: TaskCategory
    var customCategoryName: String?
    var notes: String
    var routineId: UUID?
    var tripId: UUID?
    var eventId: UUID?
    var subtasks: [Subtask]
    let createdAt: Date
    var updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        startTime: Date? = nil,
        endTime: Date? = nil,
        isCompleted: Bool = false,
        category: TaskCategory = .personal,
        customCategoryName: String? = nil,
        notes: String = "",
        routineId: UUID? = nil,
        tripId: UUID? = nil,
        eventId: UUID? = nil,
        subtasks: [Subtask] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.isCompleted = isCompleted
        self.category = category
        self.customCategoryName = customCategoryName
        self.notes = notes
        self.routineId = routineId
        self.tripId = tripId
        self.eventId = eventId
        self.subtasks = subtasks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, title, date, startTime, endTime, isCompleted
        case category, customCategoryName, notes, routineId, tripId, eventId, subtasks, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        // Map legacy "other" raw value to .custom
        let rawCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? "personal"
        category = TaskCategory(rawValue: rawCategory) ?? (rawCategory == "other" ? .custom : .personal)
        customCategoryName = try container.decodeIfPresent(String.self, forKey: .customCategoryName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        routineId = try container.decodeIfPresent(UUID.self, forKey: .routineId)
        tripId = try container.decodeIfPresent(UUID.self, forKey: .tripId)
        eventId = try container.decodeIfPresent(UUID.self, forKey: .eventId)
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    // MARK: - Subtask Helpers

    var hasSubtasks: Bool { !subtasks.isEmpty }
    var completedSubtaskCount: Int { subtasks.filter(\.isCompleted).count }
    var allSubtasksCompleted: Bool { !subtasks.isEmpty && subtasks.allSatisfy(\.isCompleted) }
    var subtaskProgress: String { "\(completedSubtaskCount)/\(subtasks.count)" }

    // MARK: - Computed Properties

    var categoryDisplayName: String {
        category == .custom ? (customCategoryName ?? "Custom") : category.displayName
    }

    var isScheduled: Bool {
        startTime != nil
    }

    var formattedTimeRange: String? {
        guard let start = startTime else { return nil }
        if let end = endTime {
            return "\(Self.timeFormatter.string(from: start)) - \(Self.timeFormatter.string(from: end))"
        }
        return Self.timeFormatter.string(from: start)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
}
