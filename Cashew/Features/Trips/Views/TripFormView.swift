import SwiftUI

struct TripFormView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TripFormViewModel
    @State private var showError = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, notes
    }

    init(viewModel: TripFormViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: viewModel.isEditing ? "Edit Trip" : "New Trip",
                subtitle: "Update trip details and media",
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    detailsCard
                    datesCard
                    notesCard
                    photosCard
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.bottom, AppTheme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: viewModel.isEditing ? "Save Trip" : "Create Trip",
                gradient: AppTheme.tripGradient,
                canConfirm: viewModel.isValid,
                isLoading: viewModel.isSaving,
                onCancel: { dismiss() },
                onConfirm: { Task { await viewModel.save() } }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .onChange(of: viewModel.error) { _, newError in
            showError = newError != nil
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave {
                dismiss()
            }
        }
    }

    private var detailsCard: some View {
        CreationSectionCard(title: "Details", icon: "airplane") {
            VStack(spacing: AppTheme.Space.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trip Name")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    TextField("e.g. Summer in Italy", text: $viewModel.name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .designField(isFocused: focusedField == .name)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Destination")
                        .font(AppTheme.TextStyle.captionBold)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    LocationSearchField(
                        text: $viewModel.destination,
                        latitude: $viewModel.destinationLatitude,
                        longitude: $viewModel.destinationLongitude,
                        label: "Destination",
                        placeholder: "Search destination..."
                    )
                    .padding(.horizontal, AppTheme.Space.md)
                    .padding(.vertical, AppTheme.Space.sm)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                }

                CreationInlineError(text: viewModel.nameError ?? viewModel.destinationError)
            }
        }
    }

    private var datesCard: some View {
        CreationSectionCard(title: "Dates", icon: "calendar") {
            VStack(spacing: AppTheme.Space.sm) {
                dateRow(
                    title: "Start Date",
                    selection: $viewModel.startDate
                )
                dateRow(
                    title: "End Date",
                    selection: $viewModel.endDate,
                    minDate: viewModel.startDate
                )
                CreationInlineError(text: viewModel.dateError)
            }
        }
    }

    private func dateRow(title: String, selection: Binding<Date>, minDate: Date? = nil) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurface)
            Spacer()
            if let minDate {
                DatePicker("", selection: selection, in: minDate..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppTheme.secondary)
            } else {
                DatePicker("", selection: selection, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppTheme.secondary)
            }
        }
        .padding(.horizontal, AppTheme.Space.md)
        .padding(.vertical, AppTheme.Space.sm)
        .background(AppTheme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var notesCard: some View {
        CreationSectionCard(title: "Notes", icon: "note.text") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.notes)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(AppTheme.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if viewModel.notes.isEmpty {
                    Text("Add notes for this trip...")
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.6))
                        .padding(.top, 16)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var photosCard: some View {
        CreationSectionCard(title: "Photos", icon: "photo") {
            PhotosPickerSection(photoAttachments: $viewModel.photoAttachments)
        }
    }
}

#Preview("Edit Trip") {
    TripFormView(
        viewModel: TripFormViewModel(
            tripService: TripService(repository: LocalTripRepository()),
            trip: Trip(
                name: "Summer Vacation",
                destination: "Paris, France",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 7)
            )
        )
    )
}
