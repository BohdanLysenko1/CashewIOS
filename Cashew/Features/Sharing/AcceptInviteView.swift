import SwiftUI

struct AcceptInviteView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let token: String

    @State private var state: ViewState = .loading

    enum ViewState {
        case loading
        case preview(ShareInvitePreview)
        case accepting(ShareInvitePreview)
        case ready(SharedResource)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    loadingView
                case .preview(let preview):
                    previewView(preview, isAccepting: false)
                case .accepting(let preview):
                    previewView(preview, isAccepting: true)
                case .ready(let resource):
                    readyView(resource)
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle("You're Invited")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadInvite() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: AppTheme.Space.md) {
            ProgressView()
            Text("Loading invite…")
                .font(.subheadline)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview

    private func previewView(_ preview: ShareInvitePreview, isAccepting: Bool) -> some View {
        VStack(spacing: AppTheme.Space.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor(for: preview.resourceType).opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: iconName(for: preview.resourceType))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(iconColor(for: preview.resourceType))
            }

            VStack(spacing: AppTheme.Space.sm) {
                Text(preview.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Shared by \(preview.createdByName)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.onSurfaceVariant)

                Text("\(resourceTypeName(for: preview.resourceType)) invite")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppTheme.Space.xs)
            }
            .padding(.horizontal, AppTheme.Space.xxl)

            Spacer()

            Button {
                Task { await acceptInvite(preview) }
            } label: {
                HStack(spacing: AppTheme.Space.sm) {
                    if isAccepting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isAccepting ? "Accepting..." : "Accept \(resourceTypeName(for: preview.resourceType))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(iconColor(for: preview.resourceType))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isAccepting)
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.bottom, AppTheme.Space.xxxl)
        }
    }

    // MARK: - Ready

    private func readyView(_ resource: SharedResource) -> some View {
        VStack(spacing: AppTheme.Space.xxl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconColor(for: resource).opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: AcceptInvitePresentation.iconName(for: resource))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(iconColor(for: resource))
            }

            // Info
            VStack(spacing: AppTheme.Space.sm) {
                Text(AcceptInvitePresentation.title(for: resource))
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if let sharedBy = AcceptInvitePresentation.sharedBy(for: resource) {
                    Text("Shared by \(sharedBy)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }

                Text(AcceptInvitePresentation.subtitle(for: resource))
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppTheme.Space.xs)
            }
            .padding(.horizontal, AppTheme.Space.xxl)

            Spacer()

            // Accept button
            Button {
                dismiss()
            } label: {
                Text("Open \(AcceptInvitePresentation.resourceTypeName(for: resource))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(iconColor(for: resource))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.bottom, AppTheme.Space.xxxl)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppTheme.Space.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.negative)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.xxl)
            Button { dismiss() } label: {
                Text("Close")
                    .primaryActionButton(gradient: AppTheme.primaryGradient, fullWidth: false)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load Invite

    private func loadInvite() async {
        do {
            let preview = try await container.shareService.previewInvite(token: token)
            state = .preview(preview)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func acceptInvite(_ preview: ShareInvitePreview) async {
        state = .accepting(preview)
        do {
            let resource = try await container.shareService.acceptInvite(token: token)
            await reload(resource)
            state = .ready(resource)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func reload(_ resource: SharedResource) async {
        switch resource {
        case .trip:
            do { try await container.tripService.loadTrips() }
            catch { print("[AcceptInviteView] Failed to reload trips: \(error)") }
        case .event:
            do { try await container.eventService.loadEvents() }
            catch { print("[AcceptInviteView] Failed to reload events: \(error)") }
        }
    }

    // MARK: - Helpers

    private func iconColor(for resource: SharedResource) -> Color {
        switch resource {
        case .trip:  return .orange
        case .event: return .pink
        }
    }

    private func iconColor(for resourceType: String) -> Color {
        resourceType == SharedResource.tripType ? .orange : .pink
    }

    private func iconName(for resourceType: String) -> String {
        resourceType == SharedResource.tripType ? "airplane.departure" : "calendar"
    }

    private func resourceTypeName(for resourceType: String) -> String {
        resourceType == SharedResource.tripType ? "Trip" : "Event"
    }
}
