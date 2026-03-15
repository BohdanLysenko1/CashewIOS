import Foundation

struct DailyRoutine: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var startTime: Date?
    var endTime: Date?
    var category: TaskCategory
    var repeatPattern: RepeatPattern
    var selectedDays: Set<DayOfWeek>
    var isEnabled: Bool
    var notes: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        category: TaskCategory = .personal,
        repeatPattern: RepeatPattern = .daily,
        selectedDays: Set<DayOfWeek> = [],
        isEnabled: Bool = true,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.repeatPattern = repeatPattern
        self.selectedDays = selectedDays
        self.isEnabled = isEnabled
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, category, repeatPattern
        case selectedDays, isEnabled, notes, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        category = try container.decodeIfPresent(TaskCategory.self, forKey: .category) ?? .personal
        repeatPattern = try container.decodeIfPresent(RepeatPattern.self, forKey: .repeatPattern) ?? .daily
        selectedDays = try container.decodeIfPresent(Set<DayOfWeek>.self, forKey: .selectedDays) ?? []
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    // MARK: - Computed Properties

    func shouldRunOn(date: Date) -> Bool {
        guard isEnabled else { return false }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        guard let dayOfWeek = DayOfWeek(rawValue: weekday) else { return false }

        switch repeatPattern {
        case .daily:
            return true
        case .weekdays:
            return repeatPattern.shouldRepeat(on: dayOfWeek)
        case .weekends:
            return repeatPattern.shouldRepeat(on: dayOfWeek)
        case .custom:
            return selectedDays.contains(dayOfWeek)
        }
    }

    var repeatDescription: String {
        switch repeatPattern {
        case .daily, .weekdays, .weekends:
            return repeatPattern.displayName
        case .custom:
            if selectedDays.isEmpty {
                return "No days selected"
            }
            if selectedDays.count == 7 {
                return "Every day"
            }
            return selectedDays
                .sorted { $0.rawValue < $1.rawValue }
                .map { $0.shortName }
                .joined(separator: ", ")
        }
    }

    func createTask(for date: Date) -> DailyTask {
        DailyTask(
            title: title,
            date: date,
            startTime: startTime,
            endTime: endTime,
            category: category,
            notes: notes,
            routineId: id
        )
    }
}
