import Foundation

/// Central source of truth for all Supabase table and column names.
/// Use these constants everywhere instead of hardcoded strings.
enum SupabaseSchema {

    enum Table {
        static let trips          = "trips"
        static let events         = "events"
        static let users          = "users"
        static let tripShares     = "trip_shares"
        static let eventShares    = "event_shares"
        static let inviteLinks    = "invite_links"
        static let dailyTasks     = "daily_tasks"
        static let dailyRoutines  = "daily_routines"
        static let devicePushTokens = "device_push_tokens"
        static let tripActivityLog = "trip_activity_log"
    }

    enum Select {
        static let tripWithOwner   = "*, owner:users!owner_id(display_name)"
        static let eventWithOwner  = "*, owner:users!owner_id(display_name)"
        static let collaboratorRow = "user:users!user_id(*)"
    }
}
