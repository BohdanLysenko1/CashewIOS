import SwiftUI

struct CollaboratorsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let resource: SharedResource

    @State private var collaborators: [AppUser] = []
    @State private var isLoading = true
    @State private var removingId: UUID?
    @State private var errorMessage: String?

    private var currentUser: AppUser? { container.authService.currentUser }

    private var isOwner: Bool {
        guard let currentUser else { return false }
        switch resource {
        case .trip(let t):  return t.ownerId == currentUser.id || t.ownerId == nil
        case .event(let e): return e.ownerId == currentUser.id || e.ownerId == nil
        }
    }

    private var resourceName: String {
        switch resource {
        case .trip(let t):  return t.name
        case .event(let e): return e.title
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Owner section
                Section("Owner") {
                    ownerRow
                }

                // Collaborators section
                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else if collaborators.isEmpty {
                        Text("No collaborators yet")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    } else {
                        ForEach(collaborators) { user in
                            collaboratorRow(user)
                        }
                    }
                } header: {
                    Text("Collaborators")
                } footer: {
                    if isOwner {
                        Text("Collaborators can view and edit this \(resourceTypeName).")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Manage Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadCollaborators() }
        }
    }

    // MARK: - Owner Row

    private var ownerRow: some View {
        HStack(spacing: 12) {
            avatar(name: ownerDisplayName, color: .blue)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ownerDisplayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Owner")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                if isOwner {
                    Text("You")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var ownerDisplayName: String {
        switch resource {
        case .trip(let t):
            if t.ownerName == nil { return currentUser?.displayName ?? "You" }
            return t.ownerName ?? "Unknown"
        case .event(let e):
            if e.ownerName == nil { return currentUser?.displayName ?? "You" }
            return e.ownerName ?? "Unknown"
        }
    }

    // MARK: - Collaborator Row

    private func collaboratorRow(_ user: AppUser) -> some View {
        HStack(spacing: 12) {
            avatar(name: user.displayName, color: .purple)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Spacer()

            if isOwner {
                if removingId == user.id {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task { await removeCollaborator(user) }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Avatar

    private func avatar(name: String, color: Color) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(color.gradient)
            .clipShape(Circle())
    }

    // MARK: - Actions

    private func loadCollaborators() async {
        isLoading = true
        do {
            collaborators = try await container.shareService.fetchCollaborators(for: resource)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func removeCollaborator(_ user: AppUser) async {
        removingId = user.id
        do {
            try await container.shareService.removeCollaborator(userId: user.id, from: resource)
            collaborators.removeAll { $0.id == user.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        removingId = nil
    }

    private var resourceTypeName: String {
        switch resource {
        case .trip:  return "trip"
        case .event: return "event"
        }
    }
}
