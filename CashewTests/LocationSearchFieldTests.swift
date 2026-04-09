import XCTest
@testable import Cashew

final class LocationSearchFieldTests: XCTestCase {

    func testProgrammaticSelectionTextChangeIsSuppressedOnce() {
        var state = LocationSearchInteractionState()

        state.willSetProgrammaticText("Barcelona, Spain")

        XCTAssertFalse(state.shouldProcessTextChange("Barcelona, Spain"))
        XCTAssertTrue(state.shouldProcessTextChange("Barcelona, Spain"))
    }

    func testManualEditAfterSelectionIsProcessed() {
        var state = LocationSearchInteractionState()

        state.willSetProgrammaticText("Barcelona, Spain")

        XCTAssertTrue(state.shouldProcessTextChange("Barcelona, Spain "))
    }

    func testAmbiguousSuggestionsUseDistinctStableIDs() {
        let spainID = LocationSuggestion.stableID(
            position: 0,
            title: "Barcelona",
            subtitle: "Spain",
            latitude: 41.3874,
            longitude: 2.1686
        )
        let usID = LocationSuggestion.stableID(
            position: 1,
            title: "Barcelona",
            subtitle: "Arkansas, United States",
            latitude: 34.8898,
            longitude: -92.1012
        )

        XCTAssertNotEqual(spainID, usID)
    }

    func testSuggestionDisplayTextPrefersCityAndCountry() {
        let suggestion = LocationSuggestion(
            id: "barcelona-spain",
            title: "Barcelona",
            subtitle: "Spain",
            displayText: "Barcelona, Spain",
            latitude: 41.3874,
            longitude: 2.1686
        )

        XCTAssertEqual(suggestion.displayText, "Barcelona, Spain")
    }

    func testNormalizedSubtitleRemovesDuplicatedCityPrefix() {
        let subtitle = LocationSuggestionText.normalizedSubtitle(
            title: "Tokyo",
            shortAddress: "Tokyo, Japan",
            country: "Japan"
        )

        XCTAssertEqual(subtitle, "Japan")
    }

    func testNormalizedSubtitleFallsBackToCountryWhenShortAddressMatchesTitle() {
        let subtitle = LocationSuggestionText.normalizedSubtitle(
            title: "Barcelona",
            shortAddress: "Barcelona",
            country: "Spain"
        )

        XCTAssertEqual(subtitle, "Spain")
    }

    func testNormalizedSubtitleAppendsCountryWhenMissingFromShortAddress() {
        let subtitle = LocationSuggestionText.normalizedSubtitle(
            title: "Paris",
            shortAddress: "Ile-de-France",
            country: "France"
        )

        XCTAssertEqual(subtitle, "Ile-de-France, France")
    }

    func testDerivedCountryFromFullAddressPrefersLastNonShortAddressSegment() {
        let country = LocationSuggestionText.derivedCountry(
            shortAddress: "Tokyo",
            fullAddress: "Shibuya City, Tokyo, Japan"
        )

        XCTAssertEqual(country, "Japan")
    }

    func testDerivedCountrySkipsNumericSegments() {
        let country = LocationSuggestionText.derivedCountry(
            shortAddress: "Downtown",
            fullAddress: "Downtown, 10001"
        )

        XCTAssertEqual(country, "")
    }
}
