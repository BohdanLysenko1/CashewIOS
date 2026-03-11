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
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)

                Image(systemName: "star.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)
            }

            VStack(spacing: 6) {
                Text("LEVEL UP!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .tracking(2)

                Text("Level \(level) · \(title)")
                    .font(.title2)
                    .fontWeight(.black)

                Text("Keep completing tasks to climb higher.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDismiss) {
                Text("Let's go!")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
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
