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

  /// v377: the stretches of a video already scanned (issue #4709). Column
  /// only, nothing to backfill: a null reads as one stretch from 0 to
  /// scanned_ms. Idempotent.
  Future<void> _assertIdentificationScannedRanges() => _addColumnIfMissing(
    'media_identification_runs',
    'scanned_ranges',
    'BLOB',
  );

  /// v381: what syncing the results needs (issue #4876): clocks on both
  /// tables, a run's origin, run id and naming bars, the decision clock, and
  /// the crops table. Each existing run gets a run id, shared by its rows.
  /// Idempotent: a run id once written is kept.
  Future<void> _assertIdentificationSyncSchema() async {
    for (final column in ['hlc', 'analysed_by', 'run_id', 'naming_bars']) {
      await _addColumnIfMissing('media_identification_runs', column, 'TEXT');
    }
    for (final column in ['hlc', 'run_id', 'decision_hlc']) {
      await _addColumnIfMissing('media_identifications', column, 'TEXT');
    }
    await Migrator(this).createTable(mediaIdentificationCrops);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_identification_crops_media '
      'ON media_identification_crops(media_id)',
    );
    // A partial schema (a test's, or a damaged file) may lack either table;
    // the backstop creates them on a later open.
    if (!await _tableExists('media_identification_runs') ||
        !await _tableExists('media_identifications')) {
      return;
    }
    await customStatement(
      'UPDATE media_identification_runs '
      'SET run_id = lower(hex(randomblob(16))) WHERE run_id IS NULL',
    );
    await customStatement(
      'UPDATE media_identifications SET run_id = ('
      'SELECT r.run_id FROM media_identification_runs r '
      'WHERE r.media_id = media_identifications.media_id) '
      'WHERE run_id IS NULL',
    );
  }
}
