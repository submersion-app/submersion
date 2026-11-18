part of '../app_database_migrations.dart';

/// What the on-device model found on each photo (issue #4668).
extension IdentificationMigrations on AppDatabase {
  /// v375: the two marine life identification tables and their media index.
  /// Idempotent. Neither table references media, so nothing is needed first.
  Future<void> _assertMediaIdentificationTables() async {
    final migrator = Migrator(this);
    await migrator.createTable(mediaIdentificationRuns);
    await migrator.createTable(mediaIdentifications);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_identifications_media '
      'ON media_identifications(media_id)',
    );
  }

  /// v376: what a video needs on both tables (issue #4675). Columns only,
  /// nothing to backfill: an existing row is a photo's. Idempotent.
  Future<void> _assertIdentificationVideoColumns() async {
    for (final column in ['scanned_ms', 'video_duration_ms']) {
      await _addColumnIfMissing('media_identification_runs', column, 'INTEGER');
    }
    for (final column in ['start_ms', 'end_ms', 'best_ms']) {
      await _addColumnIfMissing('media_identifications', column, 'INTEGER');
    }
    await _addColumnIfMissing('media_identifications', 'track_path', 'BLOB');
    await _addColumnIfMissing(
      'media_identifications',
      'claimed_species_id',
      'TEXT',
    );
    for (final column in ['confident', 'specific']) {
      await _addColumnIfMissing(
        'media_identifications',
        column,
        'INTEGER NOT NULL DEFAULT 0 CHECK ($column IN (0, 1))',
      );
    }
  }
}
