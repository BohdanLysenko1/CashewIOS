import SwiftUI
import MapKit
import CoreLocation

/// Opens Apple Maps at the given coordinates with a pin label.
struct MapLink {
    static func open(name: String, latitude: Double, longitude: Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = name
        mapItem.openInMaps()
    }
}

/// A detail row that opens Apple Maps when tapped.
struct TappableLocationRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let latitude: Double
    let longitude: Double

    var body: some View {
        Button {
            MapLink.open(name: value, latitude: latitude, longitude: longitude)
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                Text(label)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
        }
        .buttonStyle(.plain)
    }
}
