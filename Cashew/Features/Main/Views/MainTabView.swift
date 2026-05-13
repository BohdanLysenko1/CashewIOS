import SwiftUI
import UIKit

struct MainTabView: View {

    @Environment(AppContainer.self) private var container
    @Bindable private var appearance = AppearanceManager.shared
    @State private var selectedTab: Tab = .dashboard
    @State private var showLiveUpdateBanner = false
    @State private var liveUpdateMessage = ""
    @State private var liveUpdateIcon = "bolt.horizontal.circle.fill"
    @State private var liveUpdateTint: Color = .teal
    @State private var hideLiveUpdateTask: Task<Void, Never>?

    private enum Tab: Int, CaseIterable {
        case dashboard = 0
        case events
        case calendar
        case trips
        case settings

        var next: Tab? { Tab(rawValue: rawValue + 1) }
        var previous: Tab? { Tab(rawValue: rawValue - 1) }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
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
            .onChange(of: selectedTab) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .gesture(swipeGesture)

            if showLiveUpdateBanner {
                liveUpdateBanner
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .onAppear {
            configureTabBarAppearance()
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
        .onChange(of: appearance.mode) { _, _ in
            configureTabBarAppearance()
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
        guard container.authService.currentUser != nil else { return }
        (container.tripService as? TripService)?.startRealtimeSync()
        (container.eventService as? EventService)?.startRealtimeSync()
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
