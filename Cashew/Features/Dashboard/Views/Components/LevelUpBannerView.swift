import SwiftUI

struct LevelUpBannerView: View {

    let level: Int
    let title: String
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.gamificationGradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: AppTheme.tertiary.opacity(AppTheme.heroGlowOpacity), radius: 14, x: 0, y: 7)

                Image(systemName: "star.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)
            }

            VStack(spacing: 6) {
                Text("LEVEL UP!")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.tertiary)
                    .tracking(2)

                Text("Level \(level) · \(title)")
                    .font(AppTheme.TextStyle.heroTitle)
                    .foregroundStyle(AppTheme.onSurface)

                Text("Keep completing tasks to climb higher.")
                    .font(AppTheme.TextStyle.body)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDismiss) {
                Text("Let's go!")
                    .font(AppTheme.TextStyle.sectionTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.gamificationGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .background(AppTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.onSurface.opacity(AppTheme.elevatedCardBorderOpacity), lineWidth: 0.75)
        )
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        .shadow(color: AppTheme.cardAmbientShadow, radius: AppTheme.cardAmbientShadowRadius, x: 0, y: AppTheme.cardAmbientShadowY)
        .padding(.horizontal, 32)
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                appeared = true
            }
            // Staggered haptics: thud on entry, then success notification
            HapticManager.impact(.heavy)
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                HapticManager.notification(.success)
            }
        }
    }
}
