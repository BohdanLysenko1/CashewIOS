import SwiftUI

struct CalendarFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var showTrips: Bool
    @Binding var showEvents: Bool
    @Binding var showTasks: Bool
    @Binding var selectedTripStatuses: Set<TripStatus>
    @Binding var selectedEventCategories: Set<EventCategory>
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Space.lg) {
                    AppFilterSection(
                        title: "Show",
                        activeCount: hiddenContentCount,
                        onClear: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTrips = true
                                showEvents = true
                                showTasks = true
                                selectedTripStatuses.removeAll()
                                selectedEventCategories.removeAll()
                            }
                        }
                    ) {
                        HStack(spacing: 12) {
                            AppFilterToggleTile(
                                label: "Trips",
                                icon: "airplane",
                                isOn: showTrips,
                                tint: .blue,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if showTrips {
                                            showTrips = false
                                            selectedTripStatuses.removeAll()
                                        } else {
                                            showTrips = true
                                        }
                                    }
                                }
                            )
                            AppFilterToggleTile(
                                label: "Events",
                                icon: "calendar",
                                isOn: showEvents,
                                tint: .purple,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if showEvents {
                                            showEvents = false
                                            selectedEventCategories.removeAll()
                                        } else {
                                            showEvents = true
                                        }
                                    }
                                }
                            )
                            AppFilterToggleTile(
                                label: "Tasks",
                                icon: "checkmark.circle",
                                isOn: showTasks,
                                tint: .green,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showTasks.toggle()
                                    }
                                }
                            )
                        }
                    }

                    if showTrips {
                        AppFilterSection(
                            title: "Trip Status",
                            activeCount: selectedTripStatuses.count,
                            onClear: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTripStatuses.removeAll()
                                }
                            }
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Space.sm) {
                                    AppFilterChip(
                                        label: "All",
                                        isSelected: selectedTripStatuses.isEmpty,
                                        tint: .blue,
                                        selectedGradient: AppTheme.tripGradient
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTripStatuses.removeAll()
                                        }
                                    }

                                    ForEach(TripStatus.allCases, id: \.self) { status in
                                        AppFilterChip(
                                            label: status.displayName,
                                            icon: status.icon,
                                            isSelected: selectedTripStatuses.contains(status),
                                            tint: status.color,
                                            selectedGradient: AppTheme.tripGradient
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if selectedTripStatuses.contains(status) {
                                                    selectedTripStatuses.remove(status)
                                                } else {
                                                    selectedTripStatuses.insert(status)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if showEvents {
                        AppFilterSection(
                            title: "Event Category",
                            activeCount: selectedEventCategories.count,
                            onClear: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedEventCategories.removeAll()
                                }
                            }
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Space.sm) {
                                    AppFilterChip(
                                        label: "All",
                                        isSelected: selectedEventCategories.isEmpty,
                                        tint: .purple,
                                        selectedGradient: AppTheme.eventGradient
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedEventCategories.removeAll()
                                        }
                                    }

                                    ForEach(EventCategory.allCases, id: \.self) { category in
                                        AppFilterChip(
                                            label: category.displayName,
                                            icon: category.icon,
                                            isSelected: selectedEventCategories.contains(category),
                                            tint: category.color,
                                            selectedGradient: AppTheme.eventGradient
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if selectedEventCategories.contains(category) {
                                                    selectedEventCategories.remove(category)
                                                } else {
                                                    selectedEventCategories.insert(category)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(AppTheme.Space.lg)
                .animation(.spring(response: 0.3), value: showTrips)
                .animation(.spring(response: 0.3), value: showEvents)
            }
            .background(AppTheme.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if activeCount > 0 {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Reset") {
                            onReset()
                        }
                        .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private var activeCount: Int {
        [!showTrips, !showEvents, !showTasks].filter { $0 }.count
            + selectedTripStatuses.count
            + selectedEventCategories.count
    }

    private var hiddenContentCount: Int {
        [!showTrips, !showEvents, !showTasks]
            .filter { $0 }
            .count
    }
}

#Preview {
    CalendarFilterSheet(
        showTrips: .constant(true),
        showEvents: .constant(true),
        showTasks: .constant(false),
        selectedTripStatuses: .constant([.upcoming]),
        selectedEventCategories: .constant(Set<EventCategory>()),
        onReset: {}
    )
}
