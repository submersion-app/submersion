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
    // A table this creates already has diver_id; this adds its index, and
    // the column to a pre-v252 table, whichever backstop runs first.
    await _assertNavTrackDiverIdColumn();
  }

  /// v252: nav_tracks.diver_id, the route's owner, and its index.
  /// Idempotent; called from the v252 onUpgrade step and the beforeOpen
  /// backstop.
  Future<void> _assertNavTrackDiverIdColumn() async {
    if (!await _tableExists('nav_tracks')) return;
    await _addColumnIfMissing(
      'nav_tracks',
      'diver_id',
      'TEXT REFERENCES divers(id)',
    );
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_nav_tracks_diver ON nav_tracks(diver_id)
    ''');
  }

  /// v252 backfill: a linked route takes its dive's diver. An unlinked
  /// route, or one linked to an ownerless dive, stays ownerless (shared
  /// with every diver). Runs in the rung only, never in beforeOpen: a
  /// restored or adopted file keeps the owners it arrived with. Re-runs
  /// only touch rows still null.
  Future<void> _backfillNavTrackDiverIds() async {
    // Guarded on columns, like the backstops: a partially built test
    // database may hold either table without the columns this reads.
    Future<Set<String>> columnsOf(String table) async => {
      for (final c in await customSelect("PRAGMA table_info('$table')").get())
        c.read<String>('name'),
    };
    final routeColumns = await columnsOf('nav_tracks');
    final diveColumns = await columnsOf('dives');
    if (!routeColumns.containsAll(const ['dive_id', 'diver_id']) ||
        !diveColumns.containsAll(const ['id', 'diver_id'])) {
      return;
    }
    await customStatement('''
      UPDATE nav_tracks
      SET diver_id = (
        SELECT d.diver_id FROM dives d WHERE d.id = nav_tracks.dive_id
      )
      WHERE diver_id IS NULL AND dive_id IS NOT NULL
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
