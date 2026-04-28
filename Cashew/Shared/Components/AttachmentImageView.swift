import SwiftUI

/// Loads an `Attachment`'s image from local storage, falling back to Supabase Storage.
/// Provides a consistent placeholder while the remote image downloads.
struct AttachmentImageView<Placeholder: View>: View {

    let attachment: Attachment
    let contentMode: ContentMode
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

    init(
        attachment: Attachment,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { Color(.secondarySystemBackground) }
    ) {
        self.attachment = attachment
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: attachment.id) {
            loadTask?.cancel()
            loadTask = Task { @MainActor in
                let loaded = await ImageStore.loadImage(for: attachment)
                if !Task.isCancelled { image = loaded }
            }
        }
        .onDisappear { loadTask?.cancel() }
    }
}
