import Foundation

struct RecurrenceRule: Codable, Equatable, Sendable {
    var frequency: RecurrenceFrequency
    var interval: Int // every X days/weeks/months/years
    var endDate: Date?
    var occurrences: Int? // or end after X occurrences
    var daysOfWeek: Set<DayOfWeek>? // for weekly recurrence

    init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        endDate: Date? = nil,
        occurrences: Int? = nil,
        daysOfWeek: Set<DayOfWeek>? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.occurrences = occurrences
        self.daysOfWeek = daysOfWeek
    }

    private static let endDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var displayText: String {
        var text = ""

        if interval == 1 {
            text = frequency.singularName
        } else {
            text = "Every \(interval) \(frequency.pluralName)"
        }

        if let days = daysOfWeek, !days.isEmpty, frequency == .weekly {
            let dayNames = days.sorted(by: { $0.rawValue < $1.rawValue })
                .map { $0.shortName }
                .joined(separator: ", ")
            text += " on \(dayNames)"
        }

        if let end = endDate {
            text += " until \(RecurrenceRule.endDateFormatter.string(from: end))"
        } else if let count = occurrences {
            text += ", \(count) times"
        }

        return text
    }
}

enum RecurrenceFrequency: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var singularName: String {
        switch self {
        case .daily: "Every day"
        case .weekly: "Every week"
        case .monthly: "Every month"
        case .yearly: "Every year"
        }
    }

    var pluralName: String {
        switch self {
        case .daily: "days"
        case .weekly: "weeks"
        case .monthly: "months"
        case .yearly: "years"
        }
    }
}

enum DayOfWeek: Int, Codable, Sendable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var displayName: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    var initial: String {
        switch self {
        case .sunday: "S"
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        }
    }
}
