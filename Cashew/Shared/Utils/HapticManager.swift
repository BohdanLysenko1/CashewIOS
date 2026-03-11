import UIKit

enum HapticManager {

    /// Light tap — navigation, selection changes
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Success / warning / error notifications
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    /// Subtle tick for picker / selection changes
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
