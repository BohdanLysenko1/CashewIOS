import SwiftUI

actor AvatarSignedURLCache {
    static let shared = AvatarSignedURLCache()

    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]

    func value(for path: String) -> URL? {
        guard let entry = entries[path] else { return nil }
        if entry.expiresAt <= Date().addingTimeInterval(20) {
            entries.removeValue(forKey: path)
            return nil
        }
        return entry.url
    }

    func store(url: URL, for path: String, ttl: TimeInterval) {
        entries[path] = Entry(url: url, expiresAt: Date().addingTimeInterval(ttl))
    }

    func invalidate(path: String?) {
        guard let path else { return }
        entries.removeValue(forKey: path)
    }
}

struct UserAvatarView: View {
    @Environment(AppContainer.self) private var container

    let displayName: String
    let avatarPath: String?
    var size: CGFloat = 44
    var tint: Color = .blue

    @State private var signedURL: URL?

    private static let signedURLTTLSeconds = 3600

    var body: some View {
        ZStack {
            if let signedURL {
                AsyncImage(url: signedURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .task(id: avatarPath) {
            await resolveSignedURL()
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(tint.gradient)

            Text(initials)
                .font(.system(size: max(12, size * 0.36), weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        if !trimmed.isEmpty {
            return String(trimmed.prefix(2)).uppercased()
        }
        return "?"
    }

    @MainActor
    private func resolveSignedURL() async {
        guard
            let avatarPath,
            !avatarPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            signedURL = nil
            return
        }

        if let cached = await AvatarSignedURLCache.shared.value(for: avatarPath) {
            signedURL = cached
            return
        }

        do {
            let url = try await container.authService.signedAvatarURL(
                for: avatarPath,
                expiresIn: Self.signedURLTTLSeconds
            )
            signedURL = url
            await AvatarSignedURLCache.shared.store(
                url: url,
                for: avatarPath,
                ttl: TimeInterval(Self.signedURLTTLSeconds)
            )
        } catch {
            signedURL = nil
        }
    }
}
