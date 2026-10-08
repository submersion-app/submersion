part of '../app_database_migrations.dart';

/// Findings of the Data Quality Assistant.
extension QualityMigrations on AppDatabase {
  Future<void> _assertQualityFindingsSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS quality_findings (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE,
        related_dive_id TEXT REFERENCES dives (id) ON DELETE SET NULL,
        computer_id TEXT REFERENCES dive_computers (id) ON DELETE SET NULL,
        detector_id TEXT NOT NULL,
        detector_version INTEGER NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        params TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quality_findings_dive '
      'ON quality_findings (dive_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quality_findings_status '
      'ON quality_findings (status)',
    );
  }
}
