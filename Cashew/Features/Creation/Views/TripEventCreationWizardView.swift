import SwiftUI

enum CreationType {
    case trip, event
}

struct TripEventCreationWizardView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let onCreated: (UUID) -> Void

    @State private var selection: CreationType?

    var body: some View {
        if let selection {
            switch selection {
            case .trip:
                TripCreationWizardView(
                    tripService: container.tripService,
                    onCreated: onCreated,
                    onDismiss: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            case .event:
                EventCreationWizardView(
                    eventService: container.eventService,
                    onCreated: onCreated,
                    onDismiss: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        } else {
            typePicker
                .transition(.opacity)
        }
    }

    // MARK: - Type Picker

    private var typePicker: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: AppTheme.Space.sm) {
                    Text("What are you planning?")
                        .font(AppTheme.TextStyle.heroTitle)
                        .foregroundStyle(AppTheme.onSurface)
                        .multilineTextAlignment(.center)

                    Text("Choose a type to get started")
                        .font(AppTheme.TextStyle.secondary)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
                .padding(.top, AppTheme.Space.sectionBreak)
                .padding(.horizontal, AppTheme.Space.lg)

                Spacer()

                // Type cards
                VStack(spacing: AppTheme.Space.lg) {
                    typeCard(
                        title: "Trip",
                        subtitle: "Plan travel with packing list, itinerary, and budget",
                        icon: "airplane",
                        gradient: AppTheme.tripGradient,
                        type: .trip
                    )

                    typeCard(
                        title: "Event",
                        subtitle: "Schedule a one-time or recurring event",
                        icon: "star.fill",
                        gradient: AppTheme.eventGradient,
                        type: .event
                    )
                }
                .padding(.horizontal, AppTheme.Space.lg)

                Spacer()
            }

            // Dismiss button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .padding(10)
                    .background(AppTheme.surfaceContainerLow)
                    .clipShape(Circle())
            }
            .padding(.top, AppTheme.Space.xl)
            .padding(.trailing, AppTheme.Space.lg)
        }
    }

    private func typeCard(title: String, subtitle: String, icon: String, gradient: LinearGradient, type: CreationType) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeInOut(duration: 0.3)) {
                selection = type
            }
        } label: {
            HStack(spacing: AppTheme.Space.lg) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.TextStyle.title)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(AppTheme.TextStyle.secondary)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(AppTheme.cardPadding)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .shadow(color: (type == .trip ? AppTheme.secondary : Color.orange).opacity(0.28), radius: 14, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }
}
