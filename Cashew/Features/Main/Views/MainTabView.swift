import SwiftUI
import UIKit

struct MainTabView: View {

    @Environment(AppContainer.self) private var container
    @Bindable private var appearance = AppearanceManager.shared
    @State private var selectedTab: Tab = .dashboard
    @State private var coordinator = OnboardingCoordinator()
    @State private var showWelcome = false
    @State private var showCompletion = false
    @State private var showLiveUpdateBanner = false
    @State private var liveUpdateMessage = ""
    @State private var liveUpdateIcon = "bolt.horizontal.circle.fill"
    @State private var liveUpdateTint: Color = .teal
    @State private var hideLiveUpdateTask: Task<Void, Never>?
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

            if showLiveUpdateBanner {
                liveUpdateBanner
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .onAppear {
            configureTabBarAppearance()
            startOnboardingIfNeeded()
            configureRealtimeSync()
        }
        .onDisappear {
            stopRealtimeSync()
            hideLiveUpdateTask?.cancel()
        }
        .onChange(of: container.dataSyncService.isEnabled) { _, _ in
            configureRealtimeSync()
        }
        .onChange(of: (container.tripService as? TripService)?.realtimeEventCounter ?? 0) { _, newValue in
            guard
                newValue > 0,
                let message = (container.tripService as? TripService)?.realtimeIndicatorMessage
            else { return }
            presentLiveUpdate(message, icon: "airplane.circle.fill", tint: .orange)
        }
        .onChange(of: (container.eventService as? EventService)?.realtimeEventCounter ?? 0) { _, newValue in
            guard
                newValue > 0,
                let message = (container.eventService as? EventService)?.realtimeIndicatorMessage
            else { return }
            presentLiveUpdate(message, icon: "star.circle.fill", tint: .pink)
        }
        .onChange(of: coordinator.currentStep) { _, newStep in
            onStepChanged(to: newStep)
        }
        .onChange(of: appearance.mode) { _, _ in
            configureTabBarAppearance()
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

    private var liveUpdateBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: liveUpdateIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating, isActive: showLiveUpdateBanner)

            VStack(alignment: .leading, spacing: 1) {
                Text("Live Update")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.88))
                Text(liveUpdateMessage)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [liveUpdateTint.opacity(0.95), liveUpdateTint.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.24), lineWidth: 1))
        .shadow(color: liveUpdateTint.opacity(0.35), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func configureRealtimeSync() {
        guard container.dataSyncService.isEnabled else {
            stopRealtimeSync()
            return
        }
        guard let ownerID = container.authService.currentUser?.id else { return }
        (container.tripService as? TripService)?.startRealtimeSync(ownerID: ownerID)
        (container.eventService as? EventService)?.startRealtimeSync(ownerID: ownerID)
    }

    private func stopRealtimeSync() {
        (container.tripService as? TripService)?.stopRealtimeSync()
        (container.eventService as? EventService)?.stopRealtimeSync()
    }

    private func presentLiveUpdate(_ message: String, icon: String, tint: Color) {
        liveUpdateMessage = message
        liveUpdateIcon = icon
        liveUpdateTint = tint

        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
            showLiveUpdateBanner = true
        }

        hideLiveUpdateTask?.cancel()
        hideLiveUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showLiveUpdateBanner = false
                }
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(AppTheme.tabBarBackground)
        appearance.shadowColor = UIColor(AppTheme.tabBarBorder)

        let selectedColor = UIColor(AppTheme.tabBarSelectedItem)
        let unselectedColor = UIColor(AppTheme.tabBarUnselectedItem)
            .withAlphaComponent(AppTheme.tabInactiveOpacity)

        let itemAppearance = UITabBarItemAppearance(style: .stacked)
        itemAppearance.normal.iconColor = unselectedColor
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        let proxy = UITabBar.appearance()
        proxy.standardAppearance = appearance
        proxy.scrollEdgeAppearance = appearance
        proxy.tintColor = selectedColor
        proxy.unselectedItemTintColor = unselectedColor
    }
}

#Preview {
    MainTabView()
        .environment(AppContainer())
}
