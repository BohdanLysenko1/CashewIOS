import SwiftUI

@main
struct CashewApp: App {

    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .task {
                    await requestNotificationPermissionIfNeeded()
                }
        }
    }

    private func requestNotificationPermissionIfNeeded() async {
        let key = UserDefaultsKeys.hasRequestedNotificationPermission

        if !UserDefaults.standard.bool(forKey: key) {
            await container.requestNotificationPermission()
            UserDefaults.standard.set(true, forKey: key)
        } else {
            // Check current status on subsequent launches
            await container.notificationService.checkAuthorizationStatus()
        }
    }
}
