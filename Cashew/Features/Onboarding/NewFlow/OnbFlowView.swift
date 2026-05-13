import SwiftUI

/// Top-level onboarding + signup flow shown when the user is not authenticated.
///
/// 9 screens: welcome → planner → events → calendar → trips → ai-itin →
/// ai-more → paywall → signup. Once the user signs in or up via the embedded
/// AuthViewModel, RootView observes `authService.isAuthenticated` and switches
/// to MainTabView.
struct OnbFlowView: View {

    /// When set, the flow runs in "replay" mode: the auth/paywall screens are
    /// skipped and the welcome screen gains a close affordance. Used by the
    /// Replay Tutorial entry point in Settings.
    var onClose: (() -> Void)? = nil

    @Environment(AppContainer.self) private var container
    @State private var viewModel: AuthViewModel?
    @State private var step: Step = OnbFlowView.initialStepFromLaunchArgs()
    @State private var isPremium = false
    @State private var isGoingBack = false

    /// Allows visual QA to launch directly into a given step via the
    /// `-onb-step <name>` launch argument. Falls back to .welcome.
    private static func initialStepFromLaunchArgs() -> Step {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-onb-step"), i + 1 < args.count {
            switch args[i + 1] {
            case "welcome":     return .welcome
            case "planner":     return .planner
            case "events":      return .events
            case "calendar":    return .calendar
            case "trips":       return .trips
            case "ai-itin":     return .aiItinerary
            case "ai-more":     return .aiMore
            case "paywall":     return .paywall
            case "signup":      return .signup
            default: break
            }
        }
        return .welcome
    }

    enum Step: Int, CaseIterable {
        case welcome
        case planner
        case events
        case calendar
        case trips
        case aiItinerary
        case aiMore
        case paywall
        case signup

        /// Index inside the bottom-nav progress dots. Welcome and signup don't
        /// participate. Returns -1 for those.
        var dotIndex: Int {
            switch self {
            case .welcome:     return -1
            case .planner:     return 0
            case .events:      return 1
            case .calendar:    return 2
            case .trips:       return 3
            case .aiItinerary: return 4
            case .aiMore:      return 5
            case .paywall:     return 6
            case .signup:      return -1
            }
        }
    }

    private static let totalDots = 7

    var body: some View {
        ZStack {
            if let viewModel {
                content(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                OnbTheme.pageBackground
                    .ignoresSafeArea()
                    .onAppear {
                        viewModel = container.makeAuthViewModel()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    @ViewBuilder
    private func content(viewModel: AuthViewModel) -> some View {
        switch step {
        case .welcome:
            OnbWelcomeScreen(onNext: advance, onClose: onClose)
                .transition(screenTransition)
        case .planner:
            OnbDayPlannerScreen(
                onNext: advance,
                onSkip: skipToPaywall,
                onBack: goBack,
                step: step.dotIndex,
                total: Self.totalDots
            )
            .transition(screenTransition)
        case .events:
            OnbEventsScreen(
                onNext: advance,
                onSkip: skipToPaywall,
                onBack: goBack,
                step: step.dotIndex,
                total: Self.totalDots
            )
            .transition(screenTransition)
        case .calendar:
            OnbCalendarScreen(
                onNext: advance,
                onSkip: skipToPaywall,
                onBack: goBack,
                step: step.dotIndex,
                total: Self.totalDots
            )
            .transition(screenTransition)
        case .trips:
            OnbTripsScreen(
                onNext: advance,
                onSkip: skipToPaywall,
                onBack: goBack,
                step: step.dotIndex,
                total: Self.totalDots
            )
            .transition(screenTransition)
        case .aiItinerary:
            OnbAIItineraryScreen(
                onNext: advance,
                onSkip: skipToPaywall,
                onBack: goBack,
                step: step.dotIndex,
                total: Self.totalDots
            )
            .transition(screenTransition)
        case .aiMore:
            OnbAIMoreScreen(
                onNext: advance,
                onSkip: skipToPaywall,
                onBack: goBack,
                step: step.dotIndex,
                total: Self.totalDots
            )
            .transition(screenTransition)
        case .paywall:
            OnbPaywallScreen(
                onSubscribe: { isPremium = true; goTo(.signup) },
                onMaybeLater: { isPremium = false; goTo(.signup) },
                onBack: goBack,
                step: step.dotIndex,
                total: Self.totalDots
            )
            .transition(screenTransition)
        case .signup:
            OnbSignUpScreen(
                viewModel: viewModel,
                isPremium: isPremium,
                onComplete: markOnboardingComplete,
                onBack: goBack
            )
            .transition(screenTransition)
        }
    }

    private var screenTransition: AnyTransition {
        if isGoingBack {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
    }

    // MARK: - Navigation

    private func advance() {
        // In replay mode the last "tour" screen exits back to settings instead
        // of dropping into paywall/signup, which don't apply when authenticated.
        if let onClose, step == .aiMore {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onClose()
            return
        }
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isGoingBack = false
        step = next
    }

    private func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isGoingBack = true
        step = prev
    }

    private func skipToPaywall() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let onClose {
            onClose()
            return
        }
        isGoingBack = false
        step = .paywall
    }

    private func goTo(_ destination: Step) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isGoingBack = destination.rawValue < step.rawValue
        step = destination
    }

    /// Once auth completes the parent RootView will swap to MainTabView.
    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
    }
}

#Preview {
    OnbFlowView()
        .environment(AppContainer())
}
