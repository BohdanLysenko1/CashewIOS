import SwiftUI

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(AppTheme.TextStyle.bodyBold)
                .foregroundStyle(AppTheme.onSurface)
        }
    }
}

#Preview {
    List {
        DetailRow(label: "Name", value: "John Doe")
        DetailRow(label: "Status", value: "Active")
    }
}
