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
        isSelecting = true
        isShowingSuggestions = false
        completer.clear()

        let request = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: request)

        search.start { response, _ in
            if let mapItem = response?.mapItems.first {
                let coordinate = mapItem.location.coordinate
                text = [suggestion.title, suggestion.subtitle]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                latitude = coordinate.latitude
                longitude = coordinate.longitude
            } else {
                text = suggestion.title
            }
            // Delay resetting to next run-loop cycle so the onChange from setting `text` is suppressed
            Task { @MainActor in isSelecting = false }
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
        suggestions = []
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
