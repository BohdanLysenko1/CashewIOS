import UIKit

struct ImageStore {

    private static let photosDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        let dir = docs.appendingPathComponent("photos", isDirectory: true)
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
            print("[ImageStore] Failed to save image: \(error)")
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
        catch { print("[ImageStore] Failed to delete image '\(filename)': \(error)") }
    }
}
