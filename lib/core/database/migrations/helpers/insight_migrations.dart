part of '../app_database_migrations.dart';

/// Insights observations (issue #2381).
extension InsightMigrations on AppDatabase {
  /// Idempotent v265 schema: the muted-rules column on diver_settings and
  /// the insight_observation_dismissals table. Called from the v265 rung
  /// and the beforeOpen backstop. The table is skipped on a partial
  /// migration-test fixture that lacks the divers table its key points at.
  Future<void> _assertInsightObservationsSchema() async {
    await _addColumnIfMissing(
      'diver_settings',
      'insights_muted_observation_rules',
      'TEXT',
    );
    if (!await _tableExists('divers')) return;
    await Migrator(this).createTable(insightObservationDismissals);
  }
}
