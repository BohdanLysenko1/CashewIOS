import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var pendingAvatarData: Data?
    @State private var pendingAvatarImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var removeAvatar = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showChangePassword = false

    private var user: AppUser? { container.authService.currentUser }

    private var profileName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Bodo" : trimmed
    }

    private var currentAvatarPath: String? {
        user?.avatarPath
    }

    private var effectiveAvatarPath: String? {
        if removeAvatar || pendingAvatarImage != nil {
            return nil
        }
        return user?.avatarPath
    }

    private var hasChanges: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalName = user?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nameChanged = !trimmedName.isEmpty && trimmedName != originalName
        let avatarChanged = pendingAvatarData != nil || (removeAvatar && user?.avatarPath != nil)
        return nameChanged || avatarChanged
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Space.lg) {
                    headerCard
                    profileDetailsCard
                    securityCard
                    if let errorMessage {
                        errorCard(message: errorMessage)
                    }
                }
                .padding(AppTheme.Space.lg)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(!hasChanges)
                    }
                }
            }
            .onAppear {
                displayName = user?.displayName ?? ""
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await loadSelectedPhoto(item) }
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
                    .environment(container)
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: AppTheme.Space.md) {
            ZStack(alignment: .bottomTrailing) {
                avatarView(size: 96)
                    .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: 6)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.primaryGradient, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                }
            }

            VStack(spacing: 2) {
                Text(profileName)
                    .font(AppTheme.TextStyle.sectionTitle)
                    .foregroundStyle(AppTheme.onSurface)

                Text(user?.email ?? "")
                    .font(AppTheme.TextStyle.secondary)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            if currentAvatarPath != nil || pendingAvatarImage != nil {
                Button("Remove Photo", role: .destructive) {
                    pendingAvatarData = nil
                    pendingAvatarImage = nil
                    removeAvatar = true
                }
                .font(AppTheme.TextStyle.captionBold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Space.xl)
        .background(AppTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.outlineVariant, lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 20, x: 0, y: 8)
    }

    private var profileDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            Text("Display Name")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurfaceVariant)

            TextField("Your name", text: $displayName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .designField()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.lg)
        .cardStyle()
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.md) {
            Text("Security")
                .font(AppTheme.TextStyle.captionBold)
                .foregroundStyle(AppTheme.onSurfaceVariant)

            Button {
                showChangePassword = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.rotation")
                        .iconBackground(AppTheme.info)
                    Text("Change Password")
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.lg)
        .cardStyle()
    }

    private func errorCard(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.negative)
            Text(message)
                .font(AppTheme.TextStyle.secondary)
                .foregroundStyle(AppTheme.negative)
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Space.md)
        .background(AppTheme.negativeBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        if let pendingAvatarImage {
            Image(uiImage: pendingAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            UserAvatarView(
                displayName: profileName,
                avatarPath: effectiveAvatarPath,
                size: size,
                tint: AppTheme.primary
            )
        }
    }

    @MainActor
    private func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let optimizedData = image.optimizedAvatarJPEG()
            else { return }

            pendingAvatarImage = image
            pendingAvatarData = optimizedData
            removeAvatar = false
            errorMessage = nil
        } catch {
            errorMessage = "Could not load the selected image."
        }
    }

    private func save() {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Display name cannot be empty."
            return
        }

        isSaving = true
        errorMessage = nil

        let previousAvatarPath = user?.avatarPath

        Task {
            do {
                if trimmed != user?.displayName {
                    try await container.authService.updateDisplayName(trimmed)
                }

                if removeAvatar, previousAvatarPath != nil {
                    try await container.authService.removeAvatarImage()
                    await AvatarSignedURLCache.shared.invalidate(path: previousAvatarPath)
                } else if let pendingAvatarData {
                    try await container.authService.updateAvatarImage(
                        data: pendingAvatarData,
                        contentType: "image/jpeg"
                    )
                    await AvatarSignedURLCache.shared.invalidate(path: previousAvatarPath)
                    await AvatarSignedURLCache.shared.invalidate(path: container.authService.currentUser?.avatarPath)
                }

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

private extension UIImage {
    func optimizedAvatarJPEG(maxDimension: CGFloat = 1024, compression: CGFloat = 0.82) -> Data? {
        let largestSide = max(size.width, size.height)
        let targetScale = largestSide > maxDimension ? (maxDimension / largestSide) : 1
        let targetSize = CGSize(
            width: size.width * targetScale,
            height: size.height * targetScale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: compression)
    }
}
