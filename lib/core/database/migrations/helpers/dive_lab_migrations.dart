part of '../app_database_migrations.dart';

/// Saved Dive Lab scenarios.
extension DiveLabMigrations on AppDatabase {
  /// Idempotent creation of the v236 `dive_scenarios` table and its lookup
  /// index. Called from the v236 rung and the beforeOpen backstop. Skipped on
  /// a partial migration-test fixture that lacks the dives table its foreign
  /// key points at.
  Future<void> _assertDiveScenariosSchema() async {
    if (!await _tableExists('dives')) return;
    await Migrator(this).createTable(diveScenarios);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_scenarios_dive_id '
      'ON dive_scenarios(dive_id)',
    );
  }
}
