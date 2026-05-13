import SwiftUI

/// Wraps `AsyncImage` with consistent loading / failure placeholders that match
/// the AI itinerary visual language (tinted background + SF Symbol fallback).
///
/// Caller controls framing/clipping/shape externally — this view fills its
/// container, so apply `.frame(...)`, `.aspectRatio(...)`, and `.clipShape(...)`
/// on the result.
struct RemoteImageView: View {
    let url: URL?
    /// SF Symbol used in both the failure state and (optionally) the empty state.
    let fallbackSymbol: String
    /// Tint applied to placeholder backgrounds and the failure symbol.
    let tint: Color
    /// Point size for the failure symbol. Choose proportional to the caller's frame.
    var failureSymbolSize: CGFloat = 18

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty:
                ZStack {
                    tint.opacity(0.12)
                    ProgressView()
                        .controlSize(.small)
                }
            case .failure:
                ZStack {
                    tint.opacity(0.15)
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: failureSymbolSize))
                        .foregroundStyle(tint)
                }
            @unknown default:
                tint.opacity(0.15)
            }
        }
    }
}
