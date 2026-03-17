import SwiftUI
import UIKit

@Observable
@MainActor
final class OnboardingCoordinator {

    var isActive = false
    var currentStep: OnboardingStep = .welcome
    private(set) var isTransitioning = false

    private let haptics = UIImpactFeedbackGenerator(style: .light)

    /// Frames registered by each content view (global coordinates).
    /// Mutated only via registerFrame(id:frame:) — read externally through currentHighlightFrame.
    private(set) var registeredFrames: [String: CGRect] = [:]

    // MARK: - Constants

    /// Spring used for step-to-step transitions.
    private static let stepAnimation = Animation.spring(response: 0.45, dampingFraction: 0.82)
    /// Spring used when activating or restarting the tour.
    private static let activationAnimation = Animation.spring(response: 0.5, dampingFraction: 0.9)
    /// Cooldown after a transition before the next one is accepted.
    /// Slightly longer than the spring's logical completion time so rapid taps
    /// can't queue up a second transition before the first one settles.
    private static let transitionCooldown = Duration.milliseconds(500)

    // MARK: - Lifecycle

    func advance() {
        guard !isTransitioning else { return }
        isTransitioning = true
        haptics.impactOccurred()
        // complete() carries its own withAnimation — call it outside the step animation
        // block so the two animation contexts don't nest.
        if let next = currentStep.next {
            withAnimation(Self.stepAnimation) { currentStep = next }
        } else {
            complete()
        }
        Task {
            try? await Task.sleep(for: Self.transitionCooldown)
            isTransitioning = false
        }
    }

    func goBack() {
        guard !isTransitioning, let prev = currentStep.previous else { return }
        isTransitioning = true
        haptics.impactOccurred()
        withAnimation(Self.stepAnimation) {
            currentStep = prev
        }
        Task {
            try? await Task.sleep(for: Self.transitionCooldown)
            isTransitioning = false
        }
    }

    /// Activates the tour at the dashboard step. Called after the welcome screen is dismissed.
    func activate() {
        currentStep = .dashboard
        withAnimation(Self.activationAnimation) {
            isActive = true
        }
    }

    /// Restarts the tour from the dashboard step without re-showing the welcome screen.
    /// Resets the completion flag so the tour will also replay on the next cold launch.
    func restart() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        // Do NOT clear registeredFrames — views won't re-fire onGeometryChange unless
        // their geometry actually changes, so existing frames remain valid for replay.
        activate()
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        withAnimation(.easeOut(duration: 0.4)) {
            isActive = false
        }
    }

    /// Register a view's frame so the overlay can spotlight it.
    func registerFrame(id: String, frame: CGRect) {
        registeredFrames[id] = frame
    }

    var currentHighlightFrame: CGRect? {
        guard let id = currentStep.anchorId else { return nil }
        return registeredFrames[id]
    }

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
    }
}
