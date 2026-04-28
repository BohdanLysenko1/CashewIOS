import SwiftUI

/// A card that displays photo attachments in the detail views for Trip and Event.
struct PhotosGridCard: View {

    let attachments: [Attachment]
    let accentColor: Color

    @State private var viewerState: PhotoViewerState?

    private var photoAttachments: [Attachment] {
        attachments.filter { $0.type == .image && ($0.localPath != nil || $0.storagePath != nil) }
    }

    var body: some View {
        if !photoAttachments.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader

                if photoAttachments.count == 1 {
                    singlePhotoView
                } else if photoAttachments.count <= 4 {
                    compactGridView
                } else {
                    scrollableView
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .fullScreenCover(item: $viewerState) { state in
                FullScreenPhotoView(attachments: state.attachments, startIndex: state.startIndex)
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.stack")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accentColor)
            Text("Photos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.onSurfaceVariant)
            Spacer()
            Text("\(photoAttachments.count) \(photoAttachments.count == 1 ? "photo" : "photos")")
                .font(.caption)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(AppTheme.surfaceContainerLow)
    }

    // MARK: - Single Photo

    private var singlePhotoView: some View {
        Group {
            if let attachment = photoAttachments.first {
                photoButton(attachment: attachment, index: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: AppTheme.cardCornerRadius,
                            bottomTrailingRadius: AppTheme.cardCornerRadius,
                            topTrailingRadius: 0
                        )
                    )
            }
        }
    }

    // MARK: - Compact Grid (2–4 photos)

    private var compactGridView: some View {
        let total = photoAttachments.count
        let columns = total == 2
            ? [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]
            : [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(photoAttachments.indices, id: \.self) { index in
                photoButton(attachment: photoAttachments[index], index: index)
                    .frame(height: total == 2 ? 160 : 120)
                    .clipped()
                    .clipShape(bottomCorners(for: index, total: total))
            }
        }
    }

    // MARK: - Scrollable (5+ photos)

    private var scrollableView: some View {
        VStack(spacing: 2) {
            if let first = photoAttachments.first {
                photoButton(attachment: first, index: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(1..<photoAttachments.count, id: \.self) { index in
                        photoButton(attachment: photoAttachments[index], index: index)
                            .frame(width: 90, height: 90)
                            .clipped()
                    }
                }
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: AppTheme.cardCornerRadius,
                bottomTrailingRadius: AppTheme.cardCornerRadius,
                topTrailingRadius: 0
            )
        )
    }

    // MARK: - Helpers

    private func photoButton(attachment: Attachment, index: Int) -> some View {
        Button {
            viewerState = PhotoViewerState(attachments: photoAttachments, startIndex: index)
        } label: {
            AttachmentImageView(attachment: attachment, contentMode: .fill)
        }
        .buttonStyle(.plain)
    }

    private func bottomCorners(for index: Int, total: Int) -> UnevenRoundedRectangle {
        let r = AppTheme.cardCornerRadius

        if total == 2 {
            return UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: index == 0 ? r : 0,
                bottomTrailingRadius: index == 1 ? r : 0,
                topTrailingRadius: 0
            )
        }

        let lastRowStart = ((total - 1) / 3) * 3
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: index == lastRowStart ? r : 0,
            bottomTrailingRadius: index == total - 1 ? r : 0,
            topTrailingRadius: 0
        )
    }
}
