import SwiftUI

struct RootView: View {

    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            if container.authService.isRestoringSession {
                // Hold here while the stored session is being verified.
                // Showing nothing prevents the login screen from flashing
                // before we know whether the user is already signed in.
                AppTheme.background.ignoresSafeArea()
            } else if container.authService.isRecoveringPassword {
                ResetPasswordView()
            } else if container.authService.isAuthenticated {
                MainTabView()
            } else {
                OnbFlowView()
            }
        }
        .animation(.easeInOut, value: container.authService.isAuthenticated)
        .animation(.easeInOut, value: container.authService.isRecoveringPassword)
        .task(id: container.authService.currentUser?.id) {
            await container.gamificationService.refreshForCurrentUser()
        }
    }
}

#Preview {
    RootView()
        .environment(AppContainer())
}
