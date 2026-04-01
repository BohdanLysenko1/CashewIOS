import XCTest
@testable import Cashew

@MainActor
final class OfflineSyncQueueStoreTests: XCTestCase {

    func testDeleteOperationsCoalesceByEntity() async throws {
        let store = OfflineSyncQueueStore(fileURL: makeQueueFileURL())
        let entityID = UUID()

        try await store.enqueue(.delete(entityType: .trip, entityID: entityID, at: Date(timeIntervalSince1970: 100)))
        try await store.enqueue(.delete(entityType: .trip, entityID: entityID, at: Date(timeIntervalSince1970: 200)))

        let operations = try await store.readyOperations(at: .distantFuture)
        XCTAssertEqual(operations.count, 1)

        let snapshot = await MainActor.run { () -> (String?, String?, UUID?, Date?) in
            (
                operations.first?.kind.rawValue,
                operations.first?.entityType.rawValue,
                operations.first?.entityID,
                operations.first?.occurredAt
            )
        }

        XCTAssertEqual(snapshot.0, "delete")
        XCTAssertEqual(snapshot.1, "trip")
        XCTAssertEqual(snapshot.2, entityID)
        XCTAssertEqual(snapshot.3, Date(timeIntervalSince1970: 200))
    }

    func testUpsertThenDeleteCollapsesToSingleDelete() async throws {
        let store = OfflineSyncQueueStore(fileURL: makeQueueFileURL())
        let tripID = UUID()
        let trip = Trip(
            id: tripID,
            name: "Weekend",
            destination: "Austin",
            startDate: Date(timeIntervalSince1970: 1000),
            endDate: Date(timeIntervalSince1970: 2000)
        )

        try await store.enqueue(.upsert(.trip(trip), at: Date(timeIntervalSince1970: 100)))
        try await store.enqueue(.delete(entityType: .trip, entityID: tripID, at: Date(timeIntervalSince1970: 150)))

        let operations = try await store.readyOperations(at: .distantFuture)
        XCTAssertEqual(operations.count, 1)

        let snapshot = await MainActor.run { () -> (String?, Bool) in
            (
                operations.first?.kind.rawValue,
                operations.first?.payload == nil
            )
        }
        XCTAssertEqual(snapshot.0, "delete")
        XCTAssertTrue(snapshot.1)
    }

    func testRetryMetadataDefersExecutionUntilNextAttemptAt() async throws {
        let store = OfflineSyncQueueStore(fileURL: makeQueueFileURL())
        let entityID = UUID()

        try await store.enqueue(.delete(entityType: .event, entityID: entityID, at: Date()))
        guard let op = try await store.readyOperations(at: .distantFuture).first else {
            XCTFail("Expected queued operation")
            return
        }

        let delayedOperation = await MainActor.run { () -> SyncOperation in
            var copy = op
            copy.retryCount = 3
            copy.nextAttemptAt = Date().addingTimeInterval(3600)
            return copy
        }
        try await store.update(delayedOperation)

        let readyNow = try await store.readyOperations(at: Date())
        XCTAssertTrue(readyNow.isEmpty)

        let readyLater = try await store.readyOperations(at: Date().addingTimeInterval(7200))
        XCTAssertEqual(readyLater.count, 1)
        let retryCount = await MainActor.run { readyLater.first?.retryCount }
        XCTAssertEqual(retryCount, 3)
    }

    private func makeQueueFileURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineSyncQueueStoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("queue.json")
    }
}
