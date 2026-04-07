import Foundation
import XCTest

final class SupabaseMigrationInventoryTests: XCTestCase {

    func testSupabaseMigrationsMatchExpectedInventory() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repoRoot = testsDirectory.deletingLastPathComponent()
        let migrationsDirectory = repoRoot.appendingPathComponent("supabase/migrations")

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
                "20260408_db_hardening.sql",
                "20260409_rls_performance_tuning.sql"
            ]
        )
    }
}
