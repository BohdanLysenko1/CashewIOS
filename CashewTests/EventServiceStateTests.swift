import XCTest
@testable import Cashew

@MainActor
final class EventServiceStateTests: XCTestCase {

    func testUpdateEventAppendsWhenEventNotInMemory() async throws {
        let eventID = UUID()
        let event = Event(
            id: eventID,
            title: "Dinner",
            date: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_100)
        )
        let repository = MockEventRepository(savedEvent: event)
        let service = EventService(repository: repository, notificationService: nil)

        try await service.updateEvent(event)

        XCTAssertEqual(service.events.count, 1)
        XCTAssertEqual(service.events.first?.id, eventID)
        XCTAssertEqual(repository.savedIDs, [eventID])
    }

    func testUpdateEventReplacesExistingEvent() async throws {
        let eventID = UUID()
        let original = Event(
            id: eventID,
            title: "Original",
            date: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_100)
        )
        let updated = Event(
            id: eventID,
            title: "Updated",
            date: Date(timeIntervalSince1970: 2_000),
            updatedAt: Date(timeIntervalSince1970: 2_100)
        )
        let repository = MockEventRepository(savedEvent: updated, fetchedEvents: [original])
        let service = EventService(repository: repository, notificationService: nil)
        try await service.loadEvents()

        try await service.updateEvent(updated)

        XCTAssertEqual(service.events.count, 1)
        XCTAssertEqual(service.events.first?.title, "Updated")
        XCTAssertEqual(repository.savedIDs, [eventID])
    }
}

@MainActor
private final class MockEventRepository: EventRepositoryProtocol {
    var savedEvent: Event
    var fetchedEvents: [Event]
    var savedIDs: [UUID] = []

    init(savedEvent: Event, fetchedEvents: [Event] = []) {
        self.savedEvent = savedEvent
        self.fetchedEvents = fetchedEvents
    }

    func fetchAll() async throws -> [Event] {
        fetchedEvents
    }

    func fetch(by id: UUID) async throws -> Event {
        if let event = fetchedEvents.first(where: { $0.id == id }) {
            return event
        }
        throw RepositoryError.notFound
    }

    @discardableResult
    func save(_ event: Event) async throws -> Event {
        savedIDs.append(event.id)
        return savedEvent
    }

    func delete(by id: UUID) async throws {}
}
