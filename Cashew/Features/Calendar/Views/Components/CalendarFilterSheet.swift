import SwiftUI

struct CalendarFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var showTrips: Bool
    @Binding var showEvents: Bool
    @Binding var showTasks: Bool
    @Binding var selectedTripStatus: TripStatus?
    @Binding var selectedEventCategory: EventCategory?
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    filterSection("Show") {
                        HStack(spacing: 12) {
                            contentTypeTile(
                                label: "Trips",
                                icon: "airplane",
                                isOn: showTrips,
                                color: .blue,
                                onEnable: { showTrips = true },
                                onDisable: { showTrips = false; selectedTripStatus = nil }
                            )
                            contentTypeTile(
                                label: "Events",
                                icon: "calendar",
                                isOn: showEvents,
                                color: .purple,
                                onEnable: { showEvents = true },
                                onDisable: { showEvents = false; selectedEventCategory = nil }
                            )
                            contentTypeTile(
                                label: "Tasks",
                                icon: "checkmark.circle",
                                isOn: showTasks,
                                color: .green,
                                onEnable: { showTasks = true },
                                onDisable: { showTasks = false }
                            )
                        }
                    }

                    if showTrips {
                        filterSection("Trip Status") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(
                                        label: "All",
                                        icon: nil,
                                        isSelected: selectedTripStatus == nil,
                                        color: .blue
                                    ) {
                                        selectedTripStatus = nil
                                    }

                                    ForEach(TripStatus.allCases, id: \.self) { status in
                                        FilterChip(
                                            label: status.displayName,
                                            icon: status.icon,
                                            isSelected: selectedTripStatus == status,
                                            color: status.color
                                        ) {
                                            if selectedTripStatus == status {
                                                selectedTripStatus = nil
                                            } else {
                                                selectedTripStatus = status
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
                        filterSection("Event Category") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(
                                        label: "All",
                                        icon: nil,
                                        isSelected: selectedEventCategory == nil,
                                        color: .purple
                                    ) {
                                        selectedEventCategory = nil
                                    }

                                    ForEach(EventCategory.allCases, id: \.self) { category in
                                        FilterChip(
                                            label: category.displayName,
                                            icon: category.icon,
                                            isSelected: selectedEventCategory == category,
                                            color: category.color
                                        ) {
                                            if selectedEventCategory == category {
                                                selectedEventCategory = nil
                                            } else {
                                                selectedEventCategory = category
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
                .padding(20)
                .animation(.spring(response: 0.3), value: showTrips)
                .animation(.spring(response: 0.3), value: showEvents)
            }
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
        [!showTrips, !showEvents, !showTasks,
         selectedTripStatus != nil, selectedEventCategory != nil]
            .filter { $0 }.count
    }

    private func filterSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func contentTypeTile(
        label: String,
        icon: String,
        isOn: Bool,
        color: Color,
        onEnable: @escaping () -> Void,
        onDisable: @escaping () -> Void
    ) -> some View {
        Button {
            if isOn { onDisable() } else { onEnable() }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isOn ? color : Color(.tertiaryLabel))

                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOn ? color : Color(.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isOn ? color.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isOn ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected, let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CalendarFilterSheet(
        showTrips: .constant(true),
        showEvents: .constant(true),
        showTasks: .constant(false),
        selectedTripStatus: .constant(.upcoming),
        selectedEventCategory: .constant(nil),
        onReset: {}
    )
}
