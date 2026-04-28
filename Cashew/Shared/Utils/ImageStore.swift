import UIKit
import os
import Supabase

struct ImageStore {

    static let tripPhotosBucket = "trip-photos"

    private static let photosDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        let dir = docs.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let remoteCacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Caches")
        let dir = caches.appendingPathComponent("trip-photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Saves image data to disk and returns the stored filename, or nil on failure.
    static func save(_ data: Data) -> String? {
        let filename = UUID().uuidString + ".jpg"
        let url = photosDirectory.appendingPathComponent(filename)
        do {
            // Compress to JPEG before writing
            if let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.8) {
                try jpeg.write(to: url, options: .atomic)
            } else {
                try data.write(to: url, options: .atomic)
            }
            return filename
        } catch {
            Log.imageStore.error("Failed to save image: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Loads a UIImage from a stored filename.
    static func load(filename: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Deletes a stored image file.
    static func delete(filename: String) {
        let url = photosDirectory.appendingPathComponent(filename)
        do { try FileManager.default.removeItem(at: url) }
        catch { Log.imageStore.error("Failed to delete image '\(filename, privacy: .public)': \(error.localizedDescription, privacy: .public)") }
    }

    // MARK: - Remote (Supabase Storage)

    /// Uploads a locally-stored photo to the `trip-photos` bucket and returns its storage path.
    /// Storage path is `{tripId}/{uuid}.jpg` so RLS policies can match the trip prefix.
    static func uploadToTripStorage(filename: String, tripId: UUID) async -> String? {
        let localURL = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: localURL) else {
            Log.imageStore.error("Cannot read local file for upload: \(filename, privacy: .public)")
            return nil
        }

        let storagePath = "\(tripId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

        do {
            try await SupabaseManager.client.storage
                .from(tripPhotosBucket)
                .upload(
                    storagePath,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: false)
                )
            // Seed the remote cache so subsequent loads skip a network round-trip.
            try? data.write(to: remoteCacheURL(for: storagePath), options: .atomic)
            return storagePath
        } catch {
            Log.imageStore.error("Failed to upload photo: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Downloads a trip photo from Supabase Storage, using an on-disk cache to avoid re-downloads.
    static func downloadFromTripStorage(path: String) async -> UIImage? {
        let cacheURL = remoteCacheURL(for: path)
        if let cached = try? Data(contentsOf: cacheURL), let image = UIImage(data: cached) {
            return image
        }

        do {
            let data = try await SupabaseManager.client.storage
                .from(tripPhotosBucket)
                .download(path: path)
            try? data.write(to: cacheURL, options: .atomic)
            return UIImage(data: data)
        } catch {
            Log.imageStore.error("Failed to download photo '\(path, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Loads the image for an attachment: local file first, then remote cache, then remote download.
    static func loadImage(for attachment: Attachment) async -> UIImage? {
        if let filename = attachment.localPath, let image = load(filename: filename) {
            return image
        }
        if let storagePath = attachment.storagePath {
            return await downloadFromTripStorage(path: storagePath)
        }
        return nil
    }

    private static func remoteCacheURL(for storagePath: String) -> URL {
        let safeName = storagePath.replacingOccurrences(of: "/", with: "_")
        return remoteCacheDirectory.appendingPathComponent(safeName)
    }
}
