import Foundation
import XCTest

final class SupabaseMigrationInventoryTests: XCTestCase {

    func testSupabaseMigrationsMatchExpectedInventory() throws {
        guard let migrationsDirectory = findAccessibleMigrationsDirectory() else {
            throw XCTSkip(
                "supabase/migrations is not accessible from this test runtime (likely iOS simulator sandbox)."
            )
        }

        let migrationFiles = try FileManager.default.contentsOfDirectory(atPath: migrationsDirectory.path)
            .filter { $0.hasSuffix(".sql") }
            .sorted()

        XCTAssertEqual(
            migrationFiles,
            [
                "20260401_hero_background_preferences.sql",
                "20260402_delete_user_account.sql",
                "20260403_collaborator_edit_rls.sql",
                "20260404_device_push_tokens.sql",
                "20260405_trip_activity_log.sql",
                "20260406_trip_photos_storage.sql",
                "20260407_fix_rls_policies.sql",
                "20260407183516_rls_policy_consolidation.sql",
                "20260408_db_hardening.sql",
                "20260409_rls_performance_tuning.sql",
                "20260409173430_replica_identity_full_trips_events.sql",
                "20260409213219_ai_itinerary_generation.sql",
                "20260410_fix_member_update_recursion.sql",
                "20260410_gamification_xp.sql",
                "20260411_collaborator_share_access.sql",
                "20260412_fix_collaborator_visibility.sql",
                "20260414_health_check_cleanup.sql",
                "20260414182955_restore_fk_indexes.sql",
                "20260424161355_restore_delete_user_account.sql"
            ]
        )
    }

    private func findAccessibleMigrationsDirectory() -> URL? {
        let fileManager = FileManager.default

        // Works for host-side execution where source paths are directly readable.
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repoRoot = testsDirectory.deletingLastPathComponent()
        let sourcePathCandidate = repoRoot.appendingPathComponent("supabase/migrations", isDirectory: true)
        if fileManager.fileExists(atPath: sourcePathCandidate.path) {
            return sourcePathCandidate
        }

        // Supports future packaging of migrations as bundle resources.
        let bundle = Bundle(for: Self.self)
        let bundleCandidates: [URL?] = [
            bundle.resourceURL?.appendingPathComponent("supabase/migrations", isDirectory: true),
            bundle.resourceURL?.appendingPathComponent("migrations", isDirectory: true)
        ]

        for candidate in bundleCandidates.compactMap({ $0 }) {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}
