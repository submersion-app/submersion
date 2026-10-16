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
  /// Collapses each (diver, view) group onto its lowest id, carrying the most
  /// recently saved config, then creates the index. The same rule the sync
  /// merge applies to a peer's row, so every device keeps the same row.
  /// Local only: each device repairs its own copy identically, so no
  /// tombstone is written. A no-op once the index exists.
  Future<void> _assertViewConfigsUniqueIndex() async {
    // Nothing to do once the index exists, nor on a partial schema (a
    // migration test's seed) that has no view_configs table at all.
    final present = await customSelect(
      "SELECT type FROM sqlite_master WHERE "
      "(type = 'table' AND name = 'view_configs') OR "
      "(type = 'index' AND name = 'idx_view_configs_unique')",
    ).get();
    final types = {for (final r in present) r.read<String>('type')};
    if (!types.contains('table') || types.contains('index')) return;

    const newestInGroup =
        'FROM view_configs w WHERE w.diver_id = view_configs.diver_id '
        'AND w.view_mode = view_configs.view_mode '
        'ORDER BY w.updated_at DESC, w.id ASC LIMIT 1';
    await transaction(() async {
      await customStatement('''
        UPDATE view_configs SET
          config_json = (SELECT w.config_json $newestInGroup),
          updated_at = (SELECT w.updated_at $newestInGroup),
          hlc = (SELECT w.hlc $newestInGroup)
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
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_view_configs_unique
        ON view_configs(diver_id, view_mode)
      ''');
    });
  }
}
