/// Site classification junction identity: one `site_site_types` row per
/// (site, type) and one `site_tags` row per (site, tag) (v214, issue #1765).
///
/// Both junctions follow `dive_dive_types` and `dive_tags`: a surrogate uuid
/// primary key, so a re-inserted row never collides with the tombstone of the
/// row it replaced (#347), plus a unique index over the pair the row means.
/// Unlike those two, these tables have the index from the day they exist, so
/// the collapse below only ever runs against a database whose index was lost
/// (a restore of a partially migrated file). It keeps the oldest row of each
/// pair, `id` breaking ties, so every device lands on the same survivor.
///
/// With the index in place an unguarded duplicate insert THROWS, so every
/// writer must use `DoNothing`.
library;

import 'package:drift/drift.dart';

const String kSiteSiteTypesUniqueIndexName =
    'idx_site_site_types_site_type_unique';

const String kSiteTagsUniqueIndexName = 'idx_site_tags_site_tag_unique';

const String _createSiteSiteTypesIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kSiteSiteTypesUniqueIndexName '
    'ON site_site_types(site_id, site_type_id)';

const String _createSiteTagsIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kSiteTagsUniqueIndexName '
    'ON site_tags(site_id, tag_id)';

String _collapseSql(String table, String pairColumn) =>
    '''
  DELETE FROM $table WHERE rowid IN (
    SELECT rowid FROM (
      SELECT rowid, ROW_NUMBER() OVER (
        PARTITION BY site_id, $pairColumn ORDER BY created_at ASC, id ASC
      ) AS rn FROM $table
    ) WHERE rn > 1
  )
''';

Future<bool> _exists(
  DatabaseConnectionUser db,
  String type,
  String name,
) async {
  final rows = await db
      .customSelect(
        'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
        variables: [Variable<String>(type), Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

/// Asserts both junction unique indexes exist, collapsing duplicates first so
/// creating an index cannot abort. Costs two `sqlite_master` lookups when the
/// indexes are present. Self-guarding on the tables existing, so partial
/// migration-test fixtures pass through.
///
/// Called from `onCreate` (`createAll()` never builds raw-SQL indexes), the
/// v214 rung, and `beforeOpen`.
Future<void> assertSiteClassificationUniqueness(
  DatabaseConnectionUser db,
) async {
  for (final spec in const [
    (
      table: 'site_site_types',
      pair: 'site_type_id',
      index: kSiteSiteTypesUniqueIndexName,
      create: _createSiteSiteTypesIndexSql,
    ),
    (
      table: 'site_tags',
      pair: 'tag_id',
      index: kSiteTagsUniqueIndexName,
      create: _createSiteTagsIndexSql,
    ),
  ]) {
    if (!await _exists(db, 'table', spec.table)) continue;
    if (await _exists(db, 'index', spec.index)) continue;
    await db.customStatement(_collapseSql(spec.table, spec.pair));
    await db.customStatement(spec.create);
  }
}
