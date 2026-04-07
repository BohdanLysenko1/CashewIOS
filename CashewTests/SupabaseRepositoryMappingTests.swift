import Foundation
import XCTest
@testable import Cashew

@MainActor
final class SupabaseRepositoryMappingTests: XCTestCase {

    func testTripDTOToTripMapsHeroFieldsAndTimestamps() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000)
        let ownerId = UUID()
        let heroAttachmentId = UUID()

        let dto = TripDTO(
            id: UUID(),
            ownerId: ownerId,
            owner: OwnerInfo(displayName: "Alex"),
            name: "Iceland",
            destination: "Reykjavik",
            destinationLatitude: 64.1466,
            destinationLongitude: -21.9426,
            startDate: Date(timeIntervalSince1970: 3_000),
            endDate: Date(timeIntervalSince1970: 4_000),
            notes: "Pack warm layers",
            coverImageUrl: "https://example.com/cover.jpg",
            status: "planning",
            budget: 1234.5,
            currency: "USD",
            accommodationName: "Hotel",
            accommodationAddress: "Street",
            accommodationCheckIn: Date(timeIntervalSince1970: 3_100),
            accommodationCheckOut: Date(timeIntervalSince1970: 3_900),
            accommodationConfirmation: "ABC123",
            transportationType: "Flight",
            transportationDetails: "AA100",
            transportationConfirmation: "CONF-1",
            expenses: [],
            activities: [],
            packingItems: [],
            checklistItems: [],
            attachments: [],
            heroMode: "photo",
            heroColorToken: "sunset",
            heroPhotoAttachmentId: heroAttachmentId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let trip = dto.toTrip()

        XCTAssertEqual(trip.ownerId, ownerId)
        XCTAssertEqual(trip.ownerName, "Alex")
        XCTAssertEqual(trip.heroMode, "photo")
        XCTAssertEqual(trip.heroColorToken, "sunset")
        XCTAssertEqual(trip.heroPhotoAttachmentId, heroAttachmentId)
        XCTAssertEqual(trip.createdAt, createdAt)
        XCTAssertEqual(trip.updatedAt, updatedAt)
    }

    func testEventDTOToEventMapsRecurrenceHeroAndTimezoneFields() {
        let createdAt = Date(timeIntervalSince1970: 5_000)
        let updatedAt = Date(timeIntervalSince1970: 6_000)
        let ownerId = UUID()
        let tripId = UUID()
        let heroAttachmentId = UUID()
        let exceptionOne = Date(timeIntervalSince1970: 7_000)
        let exceptionTwo = Date(timeIntervalSince1970: 8_000)
        let recurrence = RecurrenceRule(
            frequency: .weekly,
            interval: 1,
            endDate: nil,
            occurrences: 10,
            daysOfWeek: [.monday, .wednesday]
        )

        let dto = EventDTO(
            id: UUID(),
            ownerId: ownerId,
            owner: OwnerInfo(displayName: "Casey"),
            title: "Standup",
            date: Date(timeIntervalSince1970: 9_000),
            endDate: Date(timeIntervalSince1970: 9_600),
            location: "HQ",
            locationLatitude: 37.0,
            locationLongitude: -122.0,
            address: "1 Main St",
            notes: "Bring notes",
            category: "work",
            isAllDay: false,
            priority: "high",
            url: "https://example.com",
            cost: 0,
            currency: "USD",
            customCategoryName: nil,
            tripId: tripId,
            reminders: [],
            recurrenceRule: recurrence,
            exceptionDates: [exceptionOne, exceptionTwo],
            timezoneIdentifier: "America/Chicago",
            attachments: [],
            heroMode: "color",
            heroColorToken: "ocean",
            heroPhotoAttachmentId: heroAttachmentId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let event = dto.toEvent()

        XCTAssertEqual(event.ownerId, ownerId)
        XCTAssertEqual(event.ownerName, "Casey")
        XCTAssertEqual(event.tripId, tripId)
        XCTAssertEqual(event.recurrenceRule, recurrence)
        XCTAssertEqual(event.exceptionDates, [exceptionOne, exceptionTwo])
        XCTAssertEqual(event.timezoneIdentifier, "America/Chicago")
        XCTAssertEqual(event.heroMode, "color")
        XCTAssertEqual(event.heroColorToken, "ocean")
        XCTAssertEqual(event.heroPhotoAttachmentId, heroAttachmentId)
        XCTAssertEqual(event.createdAt, createdAt)
        XCTAssertEqual(event.updatedAt, updatedAt)
    }
}
