import SwiftUI

struct BottomActionBar<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 20) {
            content
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(AppTheme.surfaceContainerLowest.opacity(0.80))
        .clipShape(Capsule())
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        .padding(.bottom, 8)
    }
}

struct BottomActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(AppTheme.onSurface)
        }
    }
}

extension View {
    func bottomActionBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        self.safeAreaInset(edge: .bottom) {
            BottomActionBar(content: content)
        }
    }
}
