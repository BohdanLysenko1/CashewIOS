import XCTest
@testable import Cashew

@MainActor
final class SyncOperationCodingTests: XCTestCase {

    func testSyncOperationRoundTripsThroughJSON() async throws {
        let fixture = await MainActor.run { () -> (SyncOperation, UUID) in
            let event = Event(
                title: "Flight",
                date: Date(timeIntervalSince1970: 1_000),
                location: "ORD",
                category: .travel,
                updatedAt: Date(timeIntervalSince1970: 2_000)
            )
            return (
                SyncOperation.upsert(.event(event), at: Date(timeIntervalSince1970: 3_000)),
                event.id
            )
        }
        let original = fixture.0
        let expectedEventID = fixture.1

        let encoded = try await MainActor.run {
            try JSONEncoder().encode(original)
        }
        let decoded = try await MainActor.run {
            try JSONDecoder().decode(SyncOperation.self, from: encoded)
        }

        let snapshot = await MainActor.run { () -> (String, String, UUID, Date, UUID?, String?) in
            var payloadID: UUID?
            var payloadTitle: String?
            if case .event(let decodedEvent) = decoded.payload {
                payloadID = decodedEvent.id
                payloadTitle = decodedEvent.title
            }
            return (
                decoded.kind.rawValue,
                decoded.entityType.rawValue,
                decoded.entityID,
                decoded.occurredAt,
                payloadID,
                payloadTitle
            )
        }

        XCTAssertEqual(snapshot.0, "upsert")
        XCTAssertEqual(snapshot.1, "event")
        XCTAssertEqual(snapshot.2, expectedEventID)
        XCTAssertEqual(snapshot.3, Date(timeIntervalSince1970: 3_000))
        XCTAssertEqual(snapshot.4, expectedEventID)
        XCTAssertEqual(snapshot.5, "Flight")
    }
}
