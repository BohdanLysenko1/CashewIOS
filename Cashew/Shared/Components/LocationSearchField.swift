import SwiftUI
import MapKit

struct LocationSearchField: View {

    @Binding var text: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    var label: String = "Location"
    var placeholder: String = "Search for a place..."

    @State private var completer = LocationCompleter()
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
                    completer.search(query: newValue)
                    isShowingSuggestions = !newValue.isEmpty
                    latitude = nil
                    longitude = nil
                }

            if isShowingSuggestions && !completer.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.suggestions, id: \.self) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }

                        if suggestion != completer.suggestions.last {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        let displayText = [suggestion.title, suggestion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        // Set state synchronously before going async so onChange fires
        // while isSelecting = true and doesn't re-trigger search.
        isSelecting = true
        isShowingSuggestions = false
        completer.clear()
        text = displayText

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = displayText
        request.region = MKCoordinateRegion(MKMapRect.world)
        request.resultTypes = .address

        MKLocalSearch(request: request).start { response, _ in
            // Only update coordinates — text is already set, touching it
            // again would re-trigger onChange and re-show suggestions.
            let mapItem = response?.mapItems.first(where: {
                $0.pointOfInterestCategory == nil
            }) ?? response?.mapItems.first
            if let mapItem {
                latitude = mapItem.location.coordinate.latitude
                longitude = mapItem.location.coordinate.longitude
            }
            isSelecting = false
        }
    }
}

// MARK: - Location Completer

@Observable @MainActor
private final class LocationCompleter: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {

    var suggestions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .airport, .amusementPark, .aquarium, .beach, .campground,
            .hotel, .marina, .museum, .nationalPark, .park,
            .stadium, .theater, .university, .winery, .zoo
        ])
        // Use a world-wide region so suggestions aren't biased toward the user's location
        completer.region = MKCoordinateRegion(MKMapRect.world)
        super.init()
        completer.delegate = self
    }

    func search(query: String) {
        if query.isEmpty {
            suggestions = []
        } else {
            completer.queryFragment = query
        }
    }

    func clear() {
        completer.queryFragment = ""
        suggestions = []
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !completer.queryFragment.isEmpty else { return }
        suggestions = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
