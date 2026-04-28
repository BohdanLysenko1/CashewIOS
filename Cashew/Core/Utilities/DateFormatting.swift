import Foundation

/// Shared, cached `DateFormatter` instances to avoid repeated allocations.
enum DateFormatting {

    /// "yyyy-MM-dd" — ISO date only.
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// "EEE, MMM d" — e.g. "Wed, Jun 4".
    static let shortDayMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// "HH:mm" — 24-hour time.
    static let time24: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
