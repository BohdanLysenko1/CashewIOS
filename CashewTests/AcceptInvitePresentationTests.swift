import Foundation
import XCTest
@testable import Cashew

@MainActor
final class AcceptInvitePresentationTests: XCTestCase {

    func testIconAndTypeNameMappings() {
        let trip = SharedResource.trip(Trip(name: "Trip A", destination: "A", startDate: Date(), endDate: Date()))
        let event = SharedResource.event(Event(title: "Event B", date: Date(), location: "B", category: .social))

        XCTAssertEqual(AcceptInvitePresentation.iconName(for: trip), "airplane.circle.fill")
        XCTAssertEqual(AcceptInvitePresentation.iconName(for: event), "star.circle.fill")

        XCTAssertEqual(AcceptInvitePresentation.resourceTypeName(for: trip), "Trip")
        XCTAssertEqual(AcceptInvitePresentation.resourceTypeName(for: event), "Event")
    }

    func testTitleAndSharedBy() {
        let trip = SharedResource.trip(
            Trip(
                ownerName: "Alice",
                name: "Italy",
                destination: "Rome",
                startDate: Date(),
                endDate: Date()
            )
        )

        XCTAssertEqual(AcceptInvitePresentation.title(for: trip), "Italy")
        XCTAssertEqual(AcceptInvitePresentation.sharedBy(for: trip), "Alice")
    }

    func testSubtitleUsesInjectedFormatters() {
        let tripFormatter = DateFormatter()
        tripFormatter.dateFormat = "yyyy-MM-dd"
        tripFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let eventFormatter = DateFormatter()
        eventFormatter.dateFormat = "MM/dd/yyyy"
        eventFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let trip = SharedResource.trip(
            Trip(
                name: "Dates",
                destination: "D",
                startDate: Date(timeIntervalSince1970: 0),
                endDate: Date(timeIntervalSince1970: 86_400)
            )
        )

        let event = SharedResource.event(
            Event(
                title: "Meeting",
                date: Date(timeIntervalSince1970: 0),
                location: "Office",
                category: .work
            )
        )

        let tripSubtitle = AcceptInvitePresentation.subtitle(
            for: trip,
            tripFormatter: tripFormatter,
            eventFormatter: eventFormatter
        )
        let eventSubtitle = AcceptInvitePresentation.subtitle(
            for: event,
            tripFormatter: tripFormatter,
            eventFormatter: eventFormatter
        )

        XCTAssertEqual(tripSubtitle, "1970-01-01 – 1970-01-02")
        XCTAssertEqual(eventSubtitle, "01/01/1970")
    }
}
