part of '../app_database_migrations.dart';

/// GPS surface tracks and underwater routes.
extension TrackMigrations on AppDatabase {
  /// v230: the nav_tracks table for measured underwater routes (spec
  /// 2026-09-10-underwater-nav-track-design.md, issues #1195, #1445).
  /// Idempotent (createTable is IF NOT EXISTS); called from the v230
  /// onUpgrade step and the beforeOpen backstop.
  Future<void> _assertNavTracksSchema() async {
    await Migrator(this).createTable(navTracks);
    // Added after the table first shipped on development builds of the
    // route branch; createTable leaves an existing table as it is.
    await _addColumnIfMissing('nav_tracks', 'duration_seconds', 'INTEGER');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_nav_tracks_dive ON nav_tracks(dive_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_nav_tracks_start ON nav_tracks(start_time)
    ''');
  }

  /// Idempotent DDL for the v145 gps_tracks provenance, label, and
  /// non-destructive trim-bound columns.
  ///
  /// Self-guarding like its siblings: a DB that upgraded past 145 on a
  /// parallel branch never enters the migration block, so the beforeOpen
  /// backstop is its only path to these columns.
  Future<void> _assertGpsTrackColumns() async {
    final cols = await customSelect("PRAGMA table_info('gps_tracks')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('source')) {
      await customStatement(
        "ALTER TABLE gps_tracks ADD COLUMN source TEXT NOT NULL DEFAULT 'phone'",
      );
    }
    if (!names.contains('source_ref')) {
      await customStatement(
        'ALTER TABLE gps_tracks ADD COLUMN source_ref TEXT',
      );
    }
    if (!names.contains('name')) {
      await customStatement('ALTER TABLE gps_tracks ADD COLUMN name TEXT');
    }
    if (!names.contains('trim_start_time')) {
      await customStatement(
        'ALTER TABLE gps_tracks ADD COLUMN trim_start_time INTEGER',
      );
    }
    if (!names.contains('trim_end_time')) {
      await customStatement(
        'ALTER TABLE gps_tracks ADD COLUMN trim_end_time INTEGER',
      );
    }
  }
}
