import Foundation
import os

/// Lightweight structured logging wrapper around `os.Logger`.
/// Usage: `Log.tripService.info("Loaded \(count) trips")`
enum Log {
    static let authService      = Logger(subsystem: subsystem, category: "AuthService")
    static let tripService      = Logger(subsystem: subsystem, category: "TripService")
    static let eventService     = Logger(subsystem: subsystem, category: "EventService")
    static let dayPlanner       = Logger(subsystem: subsystem, category: "DayPlanner")
    static let gamification     = Logger(subsystem: subsystem, category: "Gamification")
    static let offlineSync      = Logger(subsystem: subsystem, category: "OfflineSync")
    static let dataSync         = Logger(subsystem: subsystem, category: "DataSync")
    static let ai               = Logger(subsystem: subsystem, category: "AI")
    static let sharing          = Logger(subsystem: subsystem, category: "Sharing")
    static let notifications    = Logger(subsystem: subsystem, category: "Notifications")
    static let imageStore       = Logger(subsystem: subsystem, category: "ImageStore")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.cashew.app"
}
