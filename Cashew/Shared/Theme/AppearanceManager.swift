import SwiftUI
import Observation
import UIKit

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
@MainActor
final class AppearanceManager {
    static let shared = AppearanceManager()

    var mode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: UserDefaultsKeys.appearanceMode)
            updateResolved()
        }
    }

    private(set) var resolvedScheme: ColorScheme = .light

    var isDark: Bool { resolvedScheme == .dark }

    private init() {
        let raw = UserDefaults.standard.integer(forKey: UserDefaultsKeys.appearanceMode)
        self.mode = AppearanceMode(rawValue: raw) ?? .system
        updateResolved()
    }

    /// Call when the system appearance may have changed (e.g. on scenePhase .active).
    func syncWithSystem() {
        if mode == .system {
            updateResolved()
        }
    }

    private func updateResolved() {
        switch mode {
        case .light:
            resolvedScheme = .light
        case .dark:
            resolvedScheme = .dark
        case .system:
            let style = UITraitCollection.current.userInterfaceStyle
            resolvedScheme = style == .dark ? .dark : .light
        }
    }
}
