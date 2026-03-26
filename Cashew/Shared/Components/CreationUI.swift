import SwiftUI

struct CreationScreenBackground: View {
    let gradient: LinearGradient

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Circle()
                .fill(gradient.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 24)
                .offset(x: -140, y: -260)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 180, style: .continuous)
                .fill(AppTheme.surfaceContainerLowest.opacity(0.45))
                .frame(width: 280, height: 180)
                .blur(radius: 18)
                .offset(x: 120, y: -300)
                .ignoresSafeArea()
        }
    }
}

struct CreationTopBar: View {
    let title: String
    let subtitle: String?
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.TextStyle.title)
                    .foregroundStyle(AppTheme.onSurface)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTheme.TextStyle.secondary)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(10)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, AppTheme.Space.md)
        .padding(.bottom, AppTheme.Space.sm)
    }
}

struct CreationWizardHeader: View {
    let title: String
    let currentStep: Int
    let totalSteps: Int
    let gradient: LinearGradient
    let onClose: () -> Void

    private var stepText: String {
        "Step \(currentStep + 1) of \(totalSteps)"
    }

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(currentStep + 1) / CGFloat(totalSteps)
    }

    var body: some View {
        VStack(spacing: AppTheme.Space.sm) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .padding(10)
                        .background(AppTheme.surfaceContainerLow)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(currentStep + 1)/\(totalSteps)")
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Capsule())
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(AppTheme.TextStyle.bodyBold)
                    .foregroundStyle(AppTheme.onSurface)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)

                Text(stepText)
                    .font(AppTheme.TextStyle.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.surfaceContainerLow)
                        .frame(height: 4)
                    Capsule()
                        .fill(gradient)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: currentStep)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, AppTheme.Space.md)
        .padding(.bottom, AppTheme.Space.lg)
    }
}

struct CreationWizardNavigationBar: View {
    let isFirstStep: Bool
    let isLastStep: Bool
    let canContinue: Bool
    let isLoading: Bool
    let gradient: LinearGradient
    let finalStepTitle: String
    let onBack: () -> Void
    let onContinue: () -> Void

    private var continueTitle: String {
        isLastStep ? finalStepTitle : "Next"
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rowLayout
            columnLayout
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, AppTheme.Space.md)
        .padding(.bottom, AppTheme.Space.lg)
        .background {
            AppTheme.background
                .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: -4)
                .ignoresSafeArea()
        }
    }

    private var rowLayout: some View {
        HStack(spacing: AppTheme.Space.md) {
            backButton
                .frame(minWidth: 72)
                .opacity(isFirstStep ? 0 : 1)
                .allowsHitTesting(!isFirstStep)
            continueButton
                .frame(maxWidth: .infinity)
        }
    }

    private var columnLayout: some View {
        VStack(spacing: AppTheme.Space.sm) {
            continueButton
            if !isFirstStep {
                backButton
            }
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Text("Back")
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(isFirstStep || isLoading)
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(continueTitle)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(
            canContinue
                ? AnyShapeStyle(gradient)
                : AnyShapeStyle(AppTheme.onSurfaceVariant.opacity(0.25))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
        .disabled(!canContinue || isLoading)
    }
}

struct CreationSectionCard<Content: View>: View {
    let title: String
    let icon: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            HStack(spacing: AppTheme.Space.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
                Text(title)
                    .font(AppTheme.TextStyle.captionBold)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            content()
        }
        .padding(AppTheme.Space.lg)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 14, x: 0, y: 6)
    }
}

struct CreationBottomActionBar: View {
    let cancelTitle: String
    let confirmTitle: String
    let gradient: LinearGradient
    let canConfirm: Bool
    let isLoading: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            actionRow
            actionColumn
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, AppTheme.Space.md)
        .padding(.bottom, AppTheme.Space.lg)
        .background {
            AppTheme.background
                .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: -4)
                .ignoresSafeArea()
        }
    }

    private var actionRow: some View {
        HStack(spacing: AppTheme.Space.md) {
            cancelButton
                .frame(minWidth: 84)
            confirmButton
                .frame(maxWidth: .infinity)
        }
    }

    private var actionColumn: some View {
        VStack(spacing: AppTheme.Space.sm) {
            confirmButton
            cancelButton
        }
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(cancelTitle)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(confirmTitle)
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(
            canConfirm
                ? AnyShapeStyle(gradient)
                : AnyShapeStyle(AppTheme.onSurfaceVariant.opacity(0.25))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
        .disabled(!canConfirm || isLoading)
    }
}

struct CreationInlineError: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                Text(text)
                    .font(AppTheme.TextStyle.caption)
            }
            .foregroundStyle(.red)
        }
    }
}
