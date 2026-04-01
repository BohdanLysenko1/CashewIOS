import XCTest
@testable import Cashew

@MainActor
final class OfflineConflictResolverTests: XCTestCase {

    func testPreferRemoteWhenRemoteIsNewer() {
        let local = Date(timeIntervalSince1970: 100)
        let remote = Date(timeIntervalSince1970: 200)
        XCTAssertTrue(OfflineConflictResolver.shouldPreferRemote(remoteUpdatedAt: remote, localUpdatedAt: local))
    }

    func testDoNotPreferRemoteWhenLocalIsNewerOrEqual() {
        let newerLocal = Date(timeIntervalSince1970: 300)
        let equal = Date(timeIntervalSince1970: 200)
        XCTAssertFalse(OfflineConflictResolver.shouldPreferRemote(remoteUpdatedAt: Date(timeIntervalSince1970: 200), localUpdatedAt: newerLocal))
        XCTAssertFalse(OfflineConflictResolver.shouldPreferRemote(remoteUpdatedAt: equal, localUpdatedAt: equal))
    }

    func testSkipDeleteWhenRemoteChangedAfterDeleteWasQueued() {
        let deleteTime = Date(timeIntervalSince1970: 500)
        let newerRemote = Date(timeIntervalSince1970: 800)
        XCTAssertTrue(OfflineConflictResolver.shouldSkipDelete(deleteOccurredAt: deleteTime, remoteUpdatedAt: newerRemote))
    }

    func testDoNotSkipDeleteWhenRemoteIsOlderOrEqual() {
        let deleteTime = Date(timeIntervalSince1970: 500)
        XCTAssertFalse(OfflineConflictResolver.shouldSkipDelete(deleteOccurredAt: deleteTime, remoteUpdatedAt: Date(timeIntervalSince1970: 400)))
        XCTAssertFalse(OfflineConflictResolver.shouldSkipDelete(deleteOccurredAt: deleteTime, remoteUpdatedAt: deleteTime))
    }
}
