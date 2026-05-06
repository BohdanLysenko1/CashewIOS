import SwiftUI

struct CollaboratorsView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let resource: SharedResource

    @State private var collaborators: [AppUser] = []
    @State private var pendingInvites: [PendingShareInvite] = []
    @State private var isLoading = true
    @State private var removingId: UUID?
    @State private var cancelingInviteId: UUID?
    @State private var errorMessage: String?
    @State private var ownerProfile: AppUser?

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
                Section("Organizer") {
                    ownerRow
                }

                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else if collaborators.isEmpty {
                        Text("No members yet")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    } else {
                        ForEach(collaborators) { user in
                            collaboratorRow(user)
                        }
                    }
                } header: {
                    Text("Members")
                } footer: {
                    if isOwner {
                        Text("Members can view and edit this \(resourceTypeName). Only the organizer can remove members or delete it.")
                    } else {
                        Text("Members can view and edit this \(resourceTypeName).")
                    }
                }

                if !pendingInvites.isEmpty {
                    Section {
                        ForEach(pendingInvites) { invite in
                            pendingInviteRow(invite)
                        }
                    } header: {
                        Text("Pending")
                    } footer: {
                        if isOwner {
                            Text("These invites haven't been accepted yet. Cancel any you no longer want to honor.")
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppTheme.negative)
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
            UserAvatarView(
                displayName: ownerDisplayName,
                avatarPath: ownerAvatarPath,
                size: 36,
                tint: AppTheme.primary
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ownerDisplayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Organizer")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.primary)
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

    private var ownerId: UUID? {
        switch resource {
        case .trip(let t): return t.ownerId
        case .event(let e): return e.ownerId
        }
    }

    private var ownerAvatarPath: String? {
        if ownerId == currentUser?.id {
            return currentUser?.avatarPath
        }
        return ownerProfile?.avatarPath
    }

    // MARK: - Collaborator Row

    private func collaboratorRow(_ user: AppUser) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(
                displayName: user.displayName,
                avatarPath: user.avatarPath,
                size: 36,
                tint: .purple
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Member")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .clipShape(Capsule())
                }
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
                            .foregroundStyle(AppTheme.negative)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func pendingInviteRow(_ invite: PendingShareInvite) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(
                displayName: invite.displayName ?? "?",
                avatarPath: nil,
                size: 36,
                tint: AppTheme.warning
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(invite.displayName ?? "Pending invite")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Pending")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.warning)
                        .clipShape(Capsule())
                }
                Text("Invited \(invite.invitedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Spacer()

            if isOwner {
                if cancelingInviteId == invite.id {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task { await cancelPendingInvite(invite) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func loadCollaborators() async {
        isLoading = true
        do {
            collaborators = try await container.shareService.fetchCollaborators(for: resource)
            await loadOwnerProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        // Pending invites are best-effort: an error fetching them shouldn't block the rest.
        if isOwner {
            pendingInvites = (try? await container.shareService.fetchPendingInvites(for: resource)) ?? []
        }
        isLoading = false
    }

    private func cancelPendingInvite(_ invite: PendingShareInvite) async {
        cancelingInviteId = invite.id
        do {
            try await container.shareService.cancelPendingInvite(invite, from: resource)
            pendingInvites.removeAll { $0.id == invite.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        cancelingInviteId = nil
    }

    private func loadOwnerProfile() async {
        guard let ownerId else {
            ownerProfile = nil
            return
        }
        if ownerId == currentUser?.id {
            ownerProfile = currentUser
            return
        }
        do {
            ownerProfile = try await container.shareService.fetchUser(id: ownerId)
        } catch {
            ownerProfile = nil
        }
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
