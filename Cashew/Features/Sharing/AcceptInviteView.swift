import SwiftUI

struct AcceptInviteView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let token: String

    @State private var state: ViewState = .loading

    enum ViewState {
        case loading
        case ready(SharedResource)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    loadingView
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

    // MARK: - Ready

    private func readyView(_ resource: SharedResource) -> some View {
        VStack(spacing: AppTheme.Space.xxl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconColor(for: resource).opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: icon(for: resource))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(iconColor(for: resource))
            }

            // Info
            VStack(spacing: AppTheme.Space.sm) {
                Text(title(for: resource))
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if let sharedBy = sharedBy(for: resource) {
                    Text("Shared by \(sharedBy)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }

                Text(subtitle(for: resource))
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
                Text("Open \(resourceTypeName(for: resource))")
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
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.xxl)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load Invite

    private func loadInvite() async {
        do {
            let resource = try await container.shareService.acceptInvite(token: token)
            // Reload data so the newly shared item appears
            switch resource {
            case .trip:
                do { try await container.tripService.loadTrips() }
                catch { print("[AcceptInviteView] Failed to reload trips: \(error)") }
            case .event:
                do { try await container.eventService.loadEvents() }
                catch { print("[AcceptInviteView] Failed to reload events: \(error)") }
            }
            state = .ready(resource)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func icon(for resource: SharedResource) -> String {
        switch resource {
        case .trip:  return "airplane.circle.fill"
        case .event: return "star.circle.fill"
        }
    }

    private func iconColor(for resource: SharedResource) -> Color {
        switch resource {
        case .trip:  return .orange
        case .event: return .pink
        }
    }

    private func title(for resource: SharedResource) -> String {
        switch resource {
        case .trip(let t):  return t.name
        case .event(let e): return e.title
        }
    }

    private func subtitle(for resource: SharedResource) -> String {
        switch resource {
        case .trip(let t):
            return "\(Self.tripDateFormatter.string(from: t.startDate)) – \(Self.tripDateFormatter.string(from: t.endDate))"
        case .event(let e):
            return Self.eventDateFormatter.string(from: e.date)
        }
    }

    private static let tripDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let eventDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func sharedBy(for resource: SharedResource) -> String? {
        switch resource {
        case .trip(let t):  return t.ownerName
        case .event(let e): return e.ownerName
        }
    }

    private func resourceTypeName(for resource: SharedResource) -> String {
        switch resource {
        case .trip:  return "Trip"
        case .event: return "Event"
        }
    }
}
