part of 'app_database_migrations.dart';

/// The unique index on view_configs(diver_id, view_mode), for every file.
///
/// The v62 rung created it, but a fresh install starts at the current version
/// and never runs that rung, so only an upgraded database had it (issue
/// #3343). Without it a fresh install could hold two rows for one view, and
/// a peer row for a view held under another id failed the sync upsert on an
/// upgraded device. Split from before_open.dart, which is near the 800-line
/// limit.
extension ViewConfigsUniqueIndexBackstop on AppDatabase {
  /// Collapses duplicate views (see [_collapseViewConfigDuplicates]), then
  /// creates the index. A no-op once the index exists, and on a partial
  /// schema (a migration test's seed) with no view_configs table at all.
  Future<void> _assertViewConfigsUniqueIndex() async {
    final present = await customSelect(
      "SELECT type FROM sqlite_master WHERE "
      "(type = 'table' AND name = 'view_configs') OR "
      "(type = 'index' AND name = 'idx_view_configs_unique')",
    ).get();
    final types = {for (final r in present) r.read<String>('type')};
    if (!types.contains('table') || types.contains('index')) return;

    await transaction(() async {
      await _collapseViewConfigDuplicates();
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_view_configs_unique
        ON view_configs(diver_id, view_mode)
      ''');
    });
  }

  /// Collapses each (diver, view) group of view_configs onto its lowest id,
  /// carrying the newest config, so the unique index can be created. Run by
  /// the v62 rung too, since a database that held twins before v62 could
  /// otherwise never open.
  ///
  /// "Newest" is the order the sync merge uses (`view_config_merge.dart`): a
  /// row with an HLC beats one without, HLCs compare as clocks (their packed
  /// form sorts as they compare), then updated_at, then the lower id. A file
  /// from before the HLC column skips that part. Local only: every device
  /// repairs its own copy identically, so no tombstone is written.
  Future<void> _collapseViewConfigDuplicates() async {
    final columns = await customSelect(
      "PRAGMA table_info('view_configs')",
    ).get();
    final hasHlc = columns.any((c) => c.read<String>('name') == 'hlc');
    final order = [
      if (hasHlc) ...['w.hlc IS NULL', 'w.hlc DESC'],
      'w.updated_at DESC',
      'w.id ASC',
    ].join(', ');
    final newestInGroup =
        'FROM view_configs w WHERE w.diver_id = view_configs.diver_id '
        'AND w.view_mode = view_configs.view_mode '
        'ORDER BY $order LIMIT 1';
    await customStatement('''
      UPDATE view_configs SET
        config_json = (SELECT w.config_json $newestInGroup),
        ${hasHlc ? 'hlc = (SELECT w.hlc $newestInGroup),' : ''}
        updated_at = (SELECT w.updated_at $newestInGroup)
      WHERE id IN (
        SELECT MIN(id) FROM view_configs
        GROUP BY diver_id, view_mode HAVING COUNT(*) > 1
      )
    ''');
    await customStatement('''
      DELETE FROM view_configs WHERE id NOT IN (
        SELECT MIN(id) FROM view_configs GROUP BY diver_id, view_mode
      )
    ''');
  }
}
