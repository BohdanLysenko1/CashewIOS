import Foundation

/// UserDefaults-backed notification preferences. Each toggle and time setting
/// is persisted independently so the user's choices survive app restarts.
struct NotificationPreferences {

    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let morningBriefingEnabled     = "notif_morningBriefingEnabled"
        static let morningBriefingHour        = "notif_morningBriefingHour"
        static let morningBriefingMinute      = "notif_morningBriefingMinute"
        static let eveningWrapUpEnabled       = "notif_eveningWrapUpEnabled"
        static let eveningWrapUpHour          = "notif_eveningWrapUpHour"
        static let eveningWrapUpMinute        = "notif_eveningWrapUpMinute"
        static let taskRemindersEnabled       = "notif_taskRemindersEnabled"
        static let taskReminderLeadMinutes    = "notif_taskReminderLeadMinutes"
        static let routineNudgesEnabled       = "notif_routineNudgesEnabled"
        static let tripCountdownEnabled       = "notif_tripCountdownEnabled"
        static let streakProtectionEnabled    = "notif_streakProtectionEnabled"
        static let streakProtectionHour       = "notif_streakProtectionHour"
        static let streakProtectionMinute     = "notif_streakProtectionMinute"
        static let levelUpEnabled             = "notif_levelUpEnabled"
    }

    // MARK: - Morning Briefing

    static var morningBriefingEnabled: Bool {
        get { defaults.object(forKey: Keys.morningBriefingEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.morningBriefingEnabled) }
    }

    static var morningBriefingHour: Int {
        get { defaults.object(forKey: Keys.morningBriefingHour) as? Int ?? 8 }
        set { defaults.set(newValue, forKey: Keys.morningBriefingHour) }
    }

    static var morningBriefingMinute: Int {
        get { defaults.object(forKey: Keys.morningBriefingMinute) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Keys.morningBriefingMinute) }
    }

    // MARK: - Evening Wrap-up

    static var eveningWrapUpEnabled: Bool {
        get { defaults.object(forKey: Keys.eveningWrapUpEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.eveningWrapUpEnabled) }
    }

    static var eveningWrapUpHour: Int {
        get { defaults.object(forKey: Keys.eveningWrapUpHour) as? Int ?? 21 }
        set { defaults.set(newValue, forKey: Keys.eveningWrapUpHour) }
    }

    static var eveningWrapUpMinute: Int {
        get { defaults.object(forKey: Keys.eveningWrapUpMinute) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Keys.eveningWrapUpMinute) }
    }

    // MARK: - Task Reminders

    static var taskRemindersEnabled: Bool {
        get { defaults.object(forKey: Keys.taskRemindersEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.taskRemindersEnabled) }
    }

    static var taskReminderLeadMinutes: Int {
        get { defaults.object(forKey: Keys.taskReminderLeadMinutes) as? Int ?? 15 }
        set { defaults.set(newValue, forKey: Keys.taskReminderLeadMinutes) }
    }

    // MARK: - Routine Nudges

    static var routineNudgesEnabled: Bool {
        get { defaults.object(forKey: Keys.routineNudgesEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.routineNudgesEnabled) }
    }

    // MARK: - Trip Countdown

    static var tripCountdownEnabled: Bool {
        get { defaults.object(forKey: Keys.tripCountdownEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.tripCountdownEnabled) }
    }

    // MARK: - Streak Protection

    static var streakProtectionEnabled: Bool {
        get { defaults.object(forKey: Keys.streakProtectionEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.streakProtectionEnabled) }
    }

    static var streakProtectionHour: Int {
        get { defaults.object(forKey: Keys.streakProtectionHour) as? Int ?? 20 }
        set { defaults.set(newValue, forKey: Keys.streakProtectionHour) }
    }

    static var streakProtectionMinute: Int {
        get { defaults.object(forKey: Keys.streakProtectionMinute) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Keys.streakProtectionMinute) }
    }

    // MARK: - Level Up

    static var levelUpEnabled: Bool {
        get { defaults.object(forKey: Keys.levelUpEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.levelUpEnabled) }
    }

    // MARK: - Convenience

    static let availableLeadMinutes = [5, 10, 15, 30, 60]
}
