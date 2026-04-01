import Foundation

enum OfflineConflictResolver {
    /// Last-write-wins for upserts: remote newer timestamp overrides local pending mutation.
    static func shouldPreferRemote(remoteUpdatedAt: Date, localUpdatedAt: Date) -> Bool {
        remoteUpdatedAt > localUpdatedAt
    }

    /// For queued deletes, keep remote if it was updated after the local delete was queued.
    static func shouldSkipDelete(deleteOccurredAt: Date, remoteUpdatedAt: Date) -> Bool {
        remoteUpdatedAt > deleteOccurredAt
    }
}
