import Foundation

struct Reminder: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var interval: ReminderInterval
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        interval: ReminderInterval,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.interval = interval
        self.isEnabled = isEnabled
    }

    func triggerDate(for eventDate: Date) -> Date {
        eventDate.addingTimeInterval(-interval.seconds)
    }
}

enum ReminderInterval: String, Codable, Sendable, CaseIterable {
    case atTime
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case oneDay
    case twoDays
    case oneWeek

    var displayName: String {
        switch self {
        case .atTime: "At time of event"
        case .fiveMinutes: "5 minutes before"
        case .fifteenMinutes: "15 minutes before"
        case .thirtyMinutes: "30 minutes before"
        case .oneHour: "1 hour before"
        case .twoHours: "2 hours before"
        case .oneDay: "1 day before"
        case .twoDays: "2 days before"
        case .oneWeek: "1 week before"
        }
    }

    var notificationStartText: String {
        switch self {
        case .atTime: "now"
        case .fiveMinutes: "in 5 minutes"
        case .fifteenMinutes: "in 15 minutes"
        case .thirtyMinutes: "in 30 minutes"
        case .oneHour: "in 1 hour"
        case .twoHours: "in 2 hours"
        case .oneDay: "in 1 day"
        case .twoDays: "in 2 days"
        case .oneWeek: "in 1 week"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .atTime: 0
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .twoHours: 2 * 60 * 60
        case .oneDay: 24 * 60 * 60
        case .twoDays: 2 * 24 * 60 * 60
        case .oneWeek: 7 * 24 * 60 * 60
        }
    }
}
