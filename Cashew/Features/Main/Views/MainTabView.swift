import SwiftUI

struct MainTabView: View {

    @State private var selectedTab: Tab = .dashboard
    @State private var coordinator = OnboardingCoordinator()
    @State private var showWelcome = false
    @State private var showCompletion = false
    /// Distinguishes a "start tour" dismiss from a "skip" dismiss in onWelcomeDismissed.
    @State private var tourStartRequested = false

    private enum Tab: Int, CaseIterable {
        case dashboard = 0
        case events
        case calendar
        case trips
        case settings

        var next: Tab? { Tab(rawValue: rawValue + 1) }
        var previous: Tab? { Tab(rawValue: rawValue - 1) }
    }

    /// A binding that silently drops tab-bar taps while the onboarding overlay is active,
    /// preventing the user from desyncing the tour by tapping a different tab.
    private var lockedTabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                guard !coordinator.isActive else { return }
                selectedTab = newTab
            }
        )
    }

    var body: some View {
        ZStack {
            TabView(selection: lockedTabSelection) {
                DashboardView()
                    .tabItem { Label("My Day", systemImage: "sun.max") }
                    .tag(Tab.dashboard)

                EventsView()
                    .tabItem { Label("Events", systemImage: "star") }
                    .tag(Tab.events)

                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(Tab.calendar)

                TripsView()
                    .tabItem { Label("Trips", systemImage: "airplane") }
                    .tag(Tab.trips)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(Tab.settings)
            }
            .environment(coordinator)
            .onChange(of: selectedTab) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            // Disable swipe-to-change-tab while onboarding is active
            .gesture(swipeGesture, including: coordinator.isActive ? .none : .all)

            // Overlay — hidden for fullscreen steps (welcome / complete)
            if coordinator.isActive && !coordinator.currentStep.isFullScreen {
                OnboardingOverlayView()
                    .environment(coordinator)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear(perform: startOnboardingIfNeeded)
        .onChange(of: coordinator.currentStep) { _, newStep in
            onStepChanged(to: newStep)
        }
        // Welcome screen — shown on first launch.
        // onDismiss fires after the dismiss animation completes, replacing the
        // fragile 450 ms Task.sleep that used to coordinate the handoff.
        .fullScreenCover(isPresented: $showWelcome, onDismiss: onWelcomeDismissed) {
            WelcomeScreenView(
                onStart: { tourStartRequested = true; showWelcome = false },
                onSkip: skipTour
            )
        }
        // Completion screen — shown after the final tour step.
        // onDismiss ensures coordinator.complete() is called even if the cover
        // is dismissed by the system rather than the "Let's Go!" button.
        .fullScreenCover(isPresented: $showCompletion, onDismiss: finishTour) {
            CompletionView(onFinish: { showCompletion = false })
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .global)
            .onEnded { gesture in
                let h = gesture.translation.width
                let v = abs(gesture.translation.height)
                guard abs(h) > v else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    if h < 0, let next = selectedTab.next { selectedTab = next }
                    else if h > 0, let prev = selectedTab.previous { selectedTab = prev }
                }
            }
    }

    // MARK: - Onboarding

    private func startOnboardingIfNeeded() {
        guard !OnboardingCoordinator.hasCompleted, !coordinator.isActive, !showWelcome else { return }
        showWelcome = true
    }

    /// Called by fullScreenCover's onDismiss after the welcome sheet has fully animated out.
    /// Replaces the old 450 ms Task.sleep — onDismiss fires at the exact moment the
    /// dismiss animation completes, so there's no guesswork about device speed.
    private func onWelcomeDismissed() {
        guard tourStartRequested else { return }  // no-op when user tapped Skip
        tourStartRequested = false
        coordinator.activate()
    }

    /// User tapped "Skip Tour" on the welcome screen.
    private func skipTour() {
        showWelcome = false
        coordinator.complete()
    }

    /// Called whenever the coordinator advances to a new step.
    private func onStepChanged(to step: OnboardingStep) {
        // Drive tab selection to match the step
        if let tabIndex = step.targetTabIndex, let tab = Tab(rawValue: tabIndex) {
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = tab
            }
        }

        // fullScreenCover is presented at window level, above the overlay, so
        // there's no visual conflict — show the completion screen immediately.
        if step == .complete {
            showCompletion = true
        }
    }

    /// Called by fullScreenCover's onDismiss after the completion sheet has fully animated out.
    private func finishTour() {
        coordinator.complete()
    }
}

#Preview {
    MainTabView()
        .environment(AppContainer())
}
