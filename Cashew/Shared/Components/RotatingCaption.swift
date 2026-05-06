import SwiftUI

struct RotatingCaption: View {
    let lines: [String]
    var interval: Duration = .seconds(1.5)

    @State private var index = 0

    var body: some View {
        Text(lines[index])
            .font(AppTheme.TextStyle.body)
            .foregroundStyle(AppTheme.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .id(index)
            .transition(.opacity)
            .task {
                guard lines.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        index = (index + 1) % lines.count
                    }
                }
            }
    }
}
