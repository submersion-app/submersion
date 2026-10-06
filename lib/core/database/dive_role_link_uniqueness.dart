/// Role junction identity (v272, issue #1221): one `dive_diver_roles` row per
/// (dive, role) and one `dive_buddy_roles` row per (dive, buddy, role).
///
/// Both tables carry their unique index from the day they exist, like
/// `site_site_types` (v217), so the collapse below only ever runs against a
/// database whose index was lost (a restore of a partially migrated file).
/// It keeps the oldest row of each key, `id` breaking ties, so every device
/// lands on the same survivor. With the index in place an unguarded
/// duplicate insert THROWS, so every writer must use `DoNothing` or check
/// first.
library;

import 'package:drift/drift.dart';

const String kDiveDiverRolesUniqueIndexName =
    'idx_dive_diver_roles_dive_role_unique';

const String kDiveBuddyRolesUniqueIndexName =
    'idx_dive_buddy_roles_dive_buddy_role_unique';

const _specs = [
  (
    table: 'dive_diver_roles',
    key: 'dive_id, role_id',
    index: kDiveDiverRolesUniqueIndexName,
  ),
  (
    table: 'dive_buddy_roles',
    key: 'dive_id, buddy_id, role_id',
    index: kDiveBuddyRolesUniqueIndexName,
  ),
];

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

/// Asserts both unique indexes, collapsing duplicates first so creating an
/// index cannot abort. Self-guarding on the tables existing, so partial
/// migration-test fixtures pass through. Called from `onCreate`, the v272
/// rung and `beforeOpen`.
Future<void> assertDiveRoleLinkUniqueness(DatabaseConnectionUser db) async {
  for (final spec in _specs) {
    if (!await _exists(db, 'table', spec.table)) continue;
    if (await _exists(db, 'index', spec.index)) continue;
    await db.customStatement('''
      DELETE FROM ${spec.table} WHERE rowid IN (
        SELECT rowid FROM (
          SELECT rowid, ROW_NUMBER() OVER (
            PARTITION BY ${spec.key} ORDER BY created_at ASC, id ASC
          ) AS rn FROM ${spec.table}
        ) WHERE rn > 1
      )
    ''');
    await db.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ${spec.index} '
      'ON ${spec.table}(${spec.key})',
    );
  }
}
