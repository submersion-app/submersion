part of '../app_database_migrations.dart';

/// Safety reviews, the emergency card and incidents.
extension SafetyMigrations on AppDatabase {
  /// v123: safety review tables, index, and settings columns. Idempotent
  /// (createTable is IF NOT EXISTS; the ALTERs are PRAGMA-guarded) so it is
  /// safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertSafetyReviewSchema() async {
    final m = Migrator(this);
    await m.createTable(diveSafetyReviews);
    await m.createTable(diveSafetyFindings);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_safety_findings_dive_id '
      'ON dive_safety_findings (dive_id)',
    );
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('safety_review_enabled')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN safety_review_enabled '
        'INTEGER NOT NULL DEFAULT 1 CHECK (safety_review_enabled IN (0, 1))',
      );
    }
    if (cols.isNotEmpty && !names.contains('safety_review_disabled_rules')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN safety_review_disabled_rules '
        'TEXT',
      );
    }
  }

  /// v253: dive_safety_reviews.inputs_hash (issue #2592). Additive nullable
  /// column, no backfill: a review without one is recomputed on next view.
  /// Idempotent, so it is also the beforeOpen backstop.
  Future<void> _assertSafetyReviewInputsHashColumn() async {
    await _addColumnIfMissing('dive_safety_reviews', 'inputs_hash', 'TEXT');
  }

  /// v126: emergency_chambers table + emergency card settings columns.
  /// Idempotent so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop.
  Future<void> _assertEmergencyCardSchema() async {
    await Migrator(this).createTable(emergencyChambers);
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('hidden_chamber_ids')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN hidden_chamber_ids TEXT',
      );
    }
    if (cols.isNotEmpty && !names.contains('emergency_region')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN emergency_region TEXT',
      );
    }
  }

  /// v127: incidents table (near-miss log). Idempotent for onUpgrade +
  /// beforeOpen backstop use.
  Future<void> _assertIncidentsSchema() async {
    await Migrator(this).createTable(incidents);
  }
}
