part of '../app_database_migrations.dart';

/// Profile revision history over `dive_profile_series` (#1197).
extension ProfileSeriesHistoryMigrations on AppDatabase {
  /// Idempotent creation of profile revision metadata over
  /// `dive_profile_series` (v257).
  ///
  /// History is pointer-only: samples stay in `dive_profile_series` and this
  /// table stores parent/branch links plus a content hash for de-dup checks.
  /// Safe from both onUpgrade and beforeOpen; skipped on fixtures that do not
  /// carry the parent tables yet.
  Future<void> _assertProfileSeriesHistorySchema() async {
    for (final parent in const ['dive_profile_series', 'dives']) {
      if (!await _tableExists(parent)) return;
    }
    await customStatement('''
      CREATE TABLE IF NOT EXISTS dive_profile_series_history (
        series_id TEXT NOT NULL PRIMARY KEY
          REFERENCES dive_profile_series(id) ON DELETE CASCADE,
        dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
        parent_series_id TEXT REFERENCES dive_profile_series(id)
          ON DELETE SET NULL,
        root_series_id TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        revision_kind TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_series_history_dive_created '
      'ON dive_profile_series_history (dive_id, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_series_history_root_created '
      'ON dive_profile_series_history (root_series_id, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_series_history_dive_hash '
      'ON dive_profile_series_history (dive_id, content_hash)',
    );
  }

  /// Backfill history rows for existing series using the safest classifier
  /// the current schema supports.
  ///
  /// Runs on every open, so only series that still lack a history row are
  /// classified: the per-row source lookup is skipped for the rest.
  ///
  /// Minimal old-schema fixtures do not all carry `source_id`,
  /// `dive_data_sources`, or `source_format`, so the classifier degrades in
  /// layers rather than assuming the richest shape is always present.
  Future<void> _backfillProfileSeriesHistoryRows() async {
    final historyCols = await customSelect(
      "PRAGMA table_info('dive_profile_series_history')",
    ).get();
    if (historyCols.isEmpty) return;

    final seriesCols = await customSelect(
      "PRAGMA table_info('dive_profile_series')",
    ).get();
    if (seriesCols.isEmpty) return;
    final seriesNames = seriesCols.map((c) => c.read<String>('name')).toSet();
    if (!seriesNames.contains('id') ||
        !seriesNames.contains('dive_id') ||
        !seriesNames.contains('created_at')) {
      return;
    }

    final hasSeriesComputerId = seriesNames.contains('computer_id');
    final hasSeriesSourceId = seriesNames.contains('source_id');

    final sourceCols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final sourceNames = sourceCols.map((c) => c.read<String>('name')).toSet();
    final canReadSourceFormat =
        sourceNames.contains('id') && sourceNames.contains('source_format');
    final canReadSourceComputerId =
        sourceNames.contains('id') && sourceNames.contains('computer_id');

    final sourceChecks = <String>[];
    if (canReadSourceFormat) {
      sourceChecks.add("ds.source_format = 'dive_computer'");
    }
    if (canReadSourceComputerId) {
      sourceChecks.add('ds.computer_id IS NOT NULL');
    }

    final revisionKindCase = switch ((hasSeriesComputerId, hasSeriesSourceId)) {
      (true, true) when sourceChecks.isNotEmpty =>
        "CASE WHEN s.computer_id IS NOT NULL OR EXISTS ("
            "SELECT 1 FROM dive_data_sources ds WHERE ds.id = s.source_id "
            "AND (${sourceChecks.join(' OR ')})"
            ") THEN 'computer_import' ELSE 'legacy' END",
      (true, _) =>
        "CASE WHEN s.computer_id IS NOT NULL THEN 'computer_import' "
            "ELSE 'legacy' END",
      (false, true) when sourceChecks.isNotEmpty =>
        "CASE WHEN EXISTS ("
            "SELECT 1 FROM dive_data_sources ds WHERE ds.id = s.source_id "
            "AND (${sourceChecks.join(' OR ')})"
            ") THEN 'computer_import' ELSE 'legacy' END",
      _ => "'legacy'",
    };

    await customStatement('''
      INSERT OR IGNORE INTO dive_profile_series_history (
        series_id,
        dive_id,
        parent_series_id,
        root_series_id,
        content_hash,
        revision_kind,
        created_at
      )
      SELECT
        s.id,
        s.dive_id,
        NULL,
        s.id,
        'legacy:' || s.id,
        $revisionKindCase,
        s.created_at
      FROM dive_profile_series s
      WHERE NOT EXISTS (
        SELECT 1 FROM dive_profile_series_history h WHERE h.series_id = s.id
      )
    ''');
  }
}
