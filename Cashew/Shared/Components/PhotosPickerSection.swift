import SwiftUI
import PhotosUI

// MARK: - Photo Viewer State

struct PhotoViewerState: Identifiable {
    let id = UUID()
    let attachments: [Attachment]
    let startIndex: Int
}

// MARK: - Photos Picker Section

/// A Form `Section` showing photo tiles in a horizontal scroll.
/// The last tile is always a "+" button to add more photos.
struct PhotosPickerSection: View {

    @Binding var photoAttachments: [Attachment]

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var viewerState: PhotoViewerState?

    private let tileSize: CGFloat = 90

    private var displayableAttachments: [Attachment] {
        photoAttachments.filter { $0.type == .image && ($0.localPath != nil || $0.storagePath != nil) }
    }

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayableAttachments.indices, id: \.self) { index in
                        photoTile(attachment: displayableAttachments[index], index: index)
                    }

                    addTile
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
        } header: {
            HStack {
                Text("Photos")
                if !photoAttachments.isEmpty {
                    Text("\(photoAttachments.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                }
            }
        }
        .fullScreenCover(item: $viewerState) { state in
            FullScreenPhotoView(attachments: state.attachments, startIndex: state.startIndex)
        }
    }

    // MARK: - Photo Tile

    private func photoTile(attachment: Attachment, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                openViewer(startingAt: index)
            } label: {
                AttachmentImageView(attachment: attachment, contentMode: .fill)
                    .frame(width: tileSize, height: tileSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(duration: 0.25)) {
                    removePhoto(attachment)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 22, height: 22)
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.onSurface)
                }
            }
            .offset(x: 6, y: -6)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Add Tile

    private var addTile: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 20,
            matching: .images
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surfaceContainerLow)
                    .frame(width: tileSize, height: tileSize)

                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    .foregroundStyle(Color(.separator))
                    .frame(width: tileSize, height: tileSize)

                if isLoading {
                    ProgressView()
                        .tint(.blue)
                } else {
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        Text("Add")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await loadPhotos(from: newItems) }
        }
    }

    // MARK: - Actions

    private func openViewer(startingAt attachmentIndex: Int) {
        let attachments = displayableAttachments
        guard !attachments.isEmpty, attachments.indices.contains(attachmentIndex) else { return }
        viewerState = PhotoViewerState(attachments: attachments, startIndex: attachmentIndex)
    }

    private func removePhoto(_ attachment: Attachment) {
        if let filename = attachment.localPath {
            ImageStore.delete(filename: filename)
        }
        photoAttachments.removeAll { $0.id == attachment.id }
    }

    @MainActor
    private func loadPhotos(from items: [PhotosPickerItem]) async {
        isLoading = true
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let filename = ImageStore.save(data) {
                let attachment = Attachment(name: "Photo", type: .image, localPath: filename)
                withAnimation(.spring(duration: 0.3)) {
                    photoAttachments.append(attachment)
                }
            }
        }
        selectedItems = []
        isLoading = false
    }
}

// MARK: - UIImage + Identifiable

extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

// MARK: - Zoomable Attachment View

private struct ZoomableAttachmentView: View {
    let attachment: Attachment

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        AttachmentImageView(attachment: attachment, contentMode: .fit) {
            ProgressView().tint(.white)
        }
        .scaleEffect(scale)
        .offset(offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                }
                .onEnded { _ in
                    if scale < 1 {
                        withAnimation(.spring()) {
                            scale = 1; lastScale = 1
                            offset = .zero; lastOffset = .zero
                        }
                    } else {
                        lastScale = scale
                    }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                },
            including: scale > 1 ? .all : .subviews
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                if scale > 1 {
                    scale = 1; lastScale = 1
                    offset = .zero; lastOffset = .zero
                } else {
                    scale = 2; lastScale = 2
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photo")
        .accessibilityHint("Pinch to zoom, drag to pan, double-tap to toggle zoom")
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Full-Screen Photo Viewer

struct FullScreenPhotoView: View {
    let attachments: [Attachment]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(attachments: [Attachment], startIndex: Int = 0) {
        self.attachments = attachments
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(attachments.indices, id: \.self) { index in
                    ZoomableAttachmentView(attachment: attachments[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            HStack {
                if attachments.count > 1 {
                    Text("\(currentIndex + 1) / \(attachments.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.4), in: Capsule())
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(.darkGray).opacity(0.8))
                        .font(.system(size: 28))
                }
            }
            .padding()
        }
    }
}
