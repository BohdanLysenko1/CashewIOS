import SwiftUI

/// Design tokens for the new onboarding flow, ported from the design package's
/// `onboarding-styles.css`. Kept separate from `AppTheme` so the flow renders
/// with its own deep-navy palette regardless of the user's appearance setting.
enum OnbTheme {

    // MARK: Brand colors (from CSS root vars)

    static let primary       = Color(red: 0.21, green: 0.26, blue: 0.91)   // #3642E9
    static let primaryDim    = Color(red: 0.20, green: 0.18, blue: 0.78)   // #332DC7
    static let primarySoft   = Color(red: 0.56, green: 0.59, blue: 1.00)   // #8F97FF
    static let secondary     = Color(red: 0.45, green: 0.21, blue: 0.80)   // #7335CC
    static let tertiarySoft  = Color(red: 0.95, green: 0.49, blue: 0.77)   // #F37CC4
    static let positive      = Color(red: 0.13, green: 0.70, blue: 0.38)   // #21B362
    static let positiveBright = Color(red: 0.30, green: 0.82, blue: 0.52)  // #4dd285
    static let warning       = Color(red: 0.95, green: 0.60, blue: 0.29)   // #F2994A
    static let premiumGold   = Color(red: 0.95, green: 0.79, blue: 0.30)   // #F2C94C
    static let premiumAmber  = Color(red: 0.95, green: 0.60, blue: 0.29)   // #F2994A
    static let inkOnGold     = Color(red: 0.10, green: 0.04, blue: 0.04)   // #1A0B0B
    static let darkInk       = Color(red: 0.05, green: 0.07, blue: 0.20)   // #0D1233

    // MARK: Backgrounds

    /// Deep navy/indigo gradient used by every onboarding screen.
    static let pageBackground = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.07, blue: 0.20),    // #0D1233
            Color(red: 0.10, green: 0.04, blue: 0.26),    // #1A0B43
            Color(red: 0.03, green: 0.11, blue: 0.23)     // #081C3B
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Slightly warmer gradient used by the paywall — pulls more purple/magenta.
    static let paywallBackground = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.04, blue: 0.18),
            Color(red: 0.12, green: 0.03, blue: 0.25),
            Color(red: 0.16, green: 0.04, blue: 0.25)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Premium accent

    static let premiumGradient = LinearGradient(
        colors: [premiumGold, premiumAmber],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Pearl-white gradient used for primary CTAs on tour screens.
    static let primaryCTAGradient = LinearGradient(
        colors: [.white, Color(red: 0.84, green: 0.92, blue: 1.0)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: Typography helpers

    static func title(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func subtitle(_ size: CGFloat = 15.5) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func eyebrow() -> Font {
        .system(size: 11, weight: .heavy, design: .rounded)
    }

    static func body(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
