import SwiftUI
import MapKit

struct LocationSearchField: View {

    @Binding var text: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    var label: String = "Location"
    var placeholder: String = "Search for a place..."

    @State private var searcher = LocationSearcher()
    @State private var isShowingSuggestions = false
    /// True while we're programmatically updating `text` after a selection,
    /// so `onChange` doesn't re-trigger search and clear coordinates.
    @State private var isSelecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .textContentType(.addressCity)
                .onChange(of: text) { _, newValue in
                    guard !isSelecting else { return }
                    searcher.search(query: newValue)
                    isShowingSuggestions = !newValue.isEmpty
                    latitude = nil
                    longitude = nil
                }

            if isShowingSuggestions && !searcher.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searcher.results, id: \.self) { item in
                        Button {
                            selectItem(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.onSurface)
                                if let locality = formattedSubtitle(for: item), !locality.isEmpty {
                                    Text(locality)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.onSurfaceVariant)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func formattedSubtitle(for item: MKMapItem) -> String? {
        let placemark = item.placemark
        let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0 }

        // Drop the first component if it duplicates the item name
        let filtered = parts.drop(while: { $0 == item.name })
        let subtitle = filtered.joined(separator: ", ")
        return subtitle.isEmpty ? nil : subtitle
    }

    private func selectItem(_ item: MKMapItem) {
        let name = item.name ?? ""
        let subtitle = formattedSubtitle(for: item) ?? ""
        let displayText = [name, subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        isSelecting = true
        isShowingSuggestions = false
        searcher.clear()
        text = displayText

        // Coordinates are already on the MKMapItem — no second lookup needed.
        latitude = item.placemark.coordinate.latitude
        longitude = item.placemark.coordinate.longitude
        isSelecting = false
    }
}

// MARK: - Location Searcher

@Observable @MainActor
private final class LocationSearcher {

    var results: [MKMapItem] = []

    private var currentTask: Task<Void, Never>?

    func search(query: String) {
        currentTask?.cancel()

        guard !query.isEmpty else {
            results = []
            return
        }

        currentTask = Task {
            // Debounce: wait briefly so we don't fire a request per keystroke
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]
            request.region = MKCoordinateRegion(MKMapRect.world)

            do {
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled else { return }
                results = Array(response.mapItems.prefix(5))
            } catch {
                guard !Task.isCancelled else { return }
                results = []
            }
        }
    }

    func clear() {
        currentTask?.cancel()
        results = []
    }
}
