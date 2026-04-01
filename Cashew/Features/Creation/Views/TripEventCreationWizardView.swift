import SwiftUI

enum CreationType {
    case trip, event, task
}

enum CreationResult {
    case trip(UUID)
    case event(UUID)
    case task(UUID)
}

struct TripEventCreationWizardView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let onCreated: (CreationResult) -> Void

    @State private var selection: CreationType?

    var body: some View {
        if let selection {
            switch selection {
            case .trip:
                TripCreationWizardView(
                    tripService: container.tripService,
                    onCreated: { onCreated(.trip($0)) },
                    onDismiss: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            case .event:
                EventCreationWizardView(
                    eventService: container.eventService,
                    onCreated: { onCreated(.event($0)) },
                    onDismiss: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            case .task:
                TaskCreationWizardView(
                    service: container.dayPlannerService,
                    tripService: container.tripService,
                    eventService: container.eventService,
                    defaultDate: Date(),
                    onCreated: { onCreated(.task($0)) },
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

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Space.xl) {
                    // Header
                    VStack(spacing: AppTheme.Space.sm) {
                        Text("What are you planning?")
                            .font(AppTheme.TextStyle.heroTitle)
                            .foregroundStyle(AppTheme.onSurface)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text("Choose a type to get started")
                            .font(AppTheme.TextStyle.secondary)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                    .padding(.top, AppTheme.Space.sectionBreak)
                    .padding(.horizontal, AppTheme.Space.lg)

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

                        typeCard(
                            title: "Task",
                            subtitle: "Capture tasks with schedule, links, and subtasks",
                            icon: "checklist",
                            gradient: AppTheme.dayPlannerGradient,
                            type: .task
                        )
                    }
                    .padding(.horizontal, AppTheme.Space.lg)
                }
                .padding(.bottom, AppTheme.Space.xxxl)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(AppTheme.TextStyle.secondary)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
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
            .shadow(color: (type == .trip ? AppTheme.secondary : AppTheme.warning).opacity(0.28), radius: 14, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }
}
