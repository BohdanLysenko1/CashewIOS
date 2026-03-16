import Foundation

/// Central registry for all UserDefaults keys used across the app.
/// Using an enum prevents typos and makes keys easy to find and rename.
enum UserDefaultsKeys {
    static let isSyncEnabled = "isSyncEnabled"
    static let hasRequestedNotificationPermission = "hasRequestedNotificationPermission"
    static let customEventCategories = "customEventCategories"
    static let customTaskCategories = "customTaskCategories"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
