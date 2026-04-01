import SwiftUI

struct CheckEmailView: View {

    let email: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.14))
                    .frame(width: 100, height: 100)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            Spacer().frame(height: 32)

            // Title + body
            VStack(spacing: 12) {
                Text("Check your email")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.onSurface)

                Text("We sent a confirmation link to")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                Text(email)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.onSurface)

                Text("Tap the link in the email to activate your account and sign in.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onBack) {
                Text("Back to Sign In")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(AppTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}
