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
    @State private var interactionState = LocationSearchInteractionState()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .textContentType(.addressCity)
                .onChange(of: text) { _, newValue in
                    guard interactionState.shouldProcessTextChange(newValue) else { return }
                    searcher.search(query: newValue)
                    isShowingSuggestions = !newValue.isEmpty
                    latitude = nil
                    longitude = nil
                }

            if isShowingSuggestions && !searcher.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searcher.results) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.onSurface)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
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

    private func selectSuggestion(_ suggestion: LocationSuggestion) {
        interactionState.willSetProgrammaticText(suggestion.displayText)
        isShowingSuggestions = false
        searcher.clear()
        text = suggestion.displayText
        latitude = suggestion.latitude
        longitude = suggestion.longitude
    }
}

// MARK: - Location Searcher

@Observable @MainActor
private final class LocationSearcher {

    var results: [LocationSuggestion] = []

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
                results = response.mapItems
                    .prefix(5)
                    .enumerated()
                    .compactMap { index, item in
                        LocationSuggestion(mapItem: item, position: index)
                    }
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

struct LocationSearchInteractionState {
    private var suppressedTextChange: String?

    mutating func willSetProgrammaticText(_ text: String) {
        suppressedTextChange = text
    }

    mutating func shouldProcessTextChange(_ newText: String) -> Bool {
        if suppressedTextChange == newText {
            suppressedTextChange = nil
            return false
        }
        suppressedTextChange = nil
        return true
    }
}

struct LocationSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let displayText: String
    let latitude: Double
    let longitude: Double

    init(
        id: String,
        title: String,
        subtitle: String,
        displayText: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.displayText = displayText
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(mapItem: MKMapItem, position: Int) {
        let title = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }
        let shortAddress = mapItem.address?.shortAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fullAddress = mapItem.address?.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let country = LocationSuggestionText.derivedCountry(
            shortAddress: shortAddress,
            fullAddress: fullAddress
        )
        let subtitle = LocationSuggestionText.normalizedSubtitle(
            title: title,
            shortAddress: shortAddress,
            country: country
        )
        let displayText = subtitle.isEmpty ? title : "\(title), \(subtitle)"
        let coordinate = mapItem.location.coordinate

        self.id = Self.stableID(
            position: position,
            title: title,
            subtitle: subtitle,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        self.title = title
        self.subtitle = subtitle
        self.displayText = displayText
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    static func stableID(
        position: Int,
        title: String,
        subtitle: String,
        latitude: Double,
        longitude: Double
    ) -> String {
        "\(position)|\(title.lowercased())|\(subtitle.lowercased())|\(latitude)|\(longitude)"
    }
}

enum LocationSuggestionText {
    static func derivedCountry(shortAddress: String, fullAddress: String) -> String {
        let shortSegments = addressSegments(shortAddress)
        let fullSegments = addressSegments(fullAddress)

        for segment in fullSegments.reversed() {
            if shortSegments.contains(where: { $0.caseInsensitiveCompare(segment) == .orderedSame }) {
                continue
            }
            if segment.rangeOfCharacter(from: .letters) == nil {
                continue
            }
            return segment
        }

        return ""
    }

    static func normalizedSubtitle(title: String, shortAddress: String, country: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedShortAddress = shortAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)

        var subtitle = trimmedShortAddress

        if subtitle.caseInsensitiveCompare(trimmedTitle) == .orderedSame {
            subtitle = ""
        }

        let duplicatedPrefix = "\(trimmedTitle),"
        if subtitle.lowercased().hasPrefix(duplicatedPrefix.lowercased()) {
            subtitle.removeFirst(duplicatedPrefix.count)
            subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if subtitle.isEmpty,
           !trimmedCountry.isEmpty,
           trimmedCountry.caseInsensitiveCompare(trimmedTitle) != .orderedSame {
            subtitle = trimmedCountry
        }

        if !subtitle.isEmpty,
           !trimmedCountry.isEmpty,
           !containsCountrySegment(subtitle, country: trimmedCountry) {
            subtitle += ", \(trimmedCountry)"
        }

        return subtitle
    }

    private static func addressSegments(_ address: String) -> [String] {
        address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func containsCountrySegment(_ subtitle: String, country: String) -> Bool {
        addressSegments(subtitle)
            .contains { $0.caseInsensitiveCompare(country) == .orderedSame }
    }
}
