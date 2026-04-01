# CashewTests

This folder contains unit tests for offline sync behavior:
- `OfflineSyncQueueStoreTests.swift`
- `SyncOperationCodingTests.swift`
- `OfflineConflictResolverTests.swift`

To execute them, add an iOS Unit Testing Bundle target named `CashewTests` in Xcode,
set `@testable import Cashew`, and include these files in that test target.
