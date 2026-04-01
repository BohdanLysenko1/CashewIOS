import Foundation
import XCTest
@testable import Cashew

@MainActor
final class SharingModelTests: XCTestCase {

    func testSharedResourceMappings() {
        let trip = Trip(name: "Tokyo", destination: "Tokyo", startDate: Date(), endDate: Date())
        let event = Event(title: "Concert", date: Date(), location: "Hall", category: .social)

        let tripResource = SharedResource.trip(trip)
        let eventResource = SharedResource.event(event)

        XCTAssertEqual(tripResource.resourceType, SharedResource.tripType)
        XCTAssertEqual(tripResource.resourceId, trip.id)

        XCTAssertEqual(eventResource.resourceType, SharedResource.eventType)
        XCTAssertEqual(eventResource.resourceId, event.id)
    }

    func testShareErrorDescriptionsAreStable() {
        XCTAssertEqual(ShareError.notAuthenticated.errorDescription, "You must be signed in to share.")
        XCTAssertEqual(ShareError.expired.errorDescription, "This invite link has expired.")
        XCTAssertEqual(ShareError.invalidToken.errorDescription, "Invalid invite link.")
        XCTAssertEqual(ShareError.unknownResourceType.errorDescription, "Unknown resource type.")
    }
}
