import SwiftUI

/// Reusable Form rows for selecting or creating a custom category.
/// Shows saved categories as a horizontal swipeable strip of chips,
/// plus a text field row for entering a new name.
struct CustomCategoryPickerRows: View {

    @Binding var selectedName: String
    let savedCategories: [String]
    let onDelete: (String) -> Void

    var body: some View {
        if !savedCategories.isEmpty {
            savedStrip
        }
        newCategoryRow
    }

    // MARK: - Horizontal Strip

    private var savedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(savedCategories, id: \.self) { name in
                    chip(name: name)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(Color.clear)
    }

    // MARK: - Chip

    private func chip(name: String) -> some View {
        let isSelected = selectedName == name

        return ZStack(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    selectedName = isSelected ? "" : name
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "checkmark" : "tag.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    isSelected
                        ? AnyShapeStyle(Color.teal.gradient)
                        : AnyShapeStyle(AppTheme.surfaceContainerLow)
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected ? Color.clear : AppTheme.surfaceContainerHigh,
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(isSelected ? 0.12 : 0.05), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            // Delete button
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    if selectedName == name { selectedName = "" }
                    onDelete(name)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 18, height: 18)
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(AppTheme.onSurface)
                }
            }
            .offset(x: 5, y: -5)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - New Category Row

    private var newCategoryRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.teal)

            TextField(
                savedCategories.isEmpty
                    ? "Category name (e.g. Photography)"
                    : "Type a new name…",
                text: $selectedName
            )

            if !selectedName.isEmpty && !savedCategories.contains(selectedName) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(.teal)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: selectedName)
    }
}
