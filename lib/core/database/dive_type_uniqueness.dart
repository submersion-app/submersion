/// Dive-type junction identity: one `dive_dive_types` row per (dive, type)
/// -- issue #1360.
///
/// `dive_dive_types` is the structural twin of `dive_tags`: a surrogate uuid
/// primary key, deliberately chosen so a re-inserted row never collides with
/// the tombstone of the row it replaced (the composite-key sync data-loss trap
/// of #347), and no constraint at all on the pair the row actually means. The
/// junction is a SET semantically and a BAG structurally, and nothing closed
/// that gap.
///
/// Two producers exploited it:
///
///  * The v92 seed (`kSeedDiveDiveTypesSql`) mints a random id per row and had
///    no re-run guard, unlike its `INSERT OR IGNORE` sibling
///    `kSeedBuiltInDiveTypesSql`. Every device that upgraded through v92 minted
///    its OWN ids for the same (dive, type) pairs.
///  * The sync merge keys junction rows on that id, so those independently
///    minted rows are distinct records and the merge keeps all of them. A
///    fleet of N devices that each upgraded through v92 converged on N badges
///    per dive.
///
/// `dive_tags` got exactly this repair in v149 for issue #1032; this is the
/// same treatment applied to the junction that was left behind. With the index
/// in place a peer's duplicate physically cannot be inserted, so the collapse
/// below needs no tombstones to stick -- and deliberately writes none, since a
/// tombstone racing ahead of the survivor would leave a device holding neither
/// row.
///
/// Every writer must therefore be conflict-safe: with an index in place an
/// unguarded duplicate insert THROWS, and a throw inside the sync merge is far
/// worse than the duplicate it replaces.
library;

import 'package:drift/drift.dart';

/// Unique index over the `dive_dive_types` junction, keyed on (dive, type).
const String kDiveDiveTypesUniqueIndexName =
    'idx_dive_dive_types_dive_type_unique';

/// One junction row per (dive, dive type). The surrogate `id` stays the
/// primary key so a re-inserted row never collides with the tombstone of the
/// row it replaced (#347).
const String kCreateDiveDiveTypesUniqueIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kDiveDiveTypesUniqueIndexName '
    'ON dive_dive_types(dive_id, dive_type_id)';

/// Keeps one junction row per (dive, type): the oldest, `id` breaking ties.
///
/// The survivor's `created_at` is load-bearing rather than arbitrary. A dive's
/// types read back ordered by it, and the FIRST is the dive's representative
/// type, so keeping the oldest row of a duplicated pair leaves the badge order
/// the diver already sees untouched. A plain `MIN(rowid)` would instead keep
/// whichever copy this device happened to insert first, which for a row that
/// arrived by sync is unrelated to when the type was actually put on the dive.
///
/// The tie-break is `id` and NOT `rowid` because it has to be a property of the
/// ROWS rather than of this device, so every device that runs this lands on the
/// same survivor. `rowid` is local insertion order: two devices holding the
/// same two rows can have received them in opposite orders, and each would keep
/// a different id. Both would then show one badge and look repaired -- but sync
/// deletions are keyed on `id`, so a later "remove this type" would tombstone
/// an id the peer does not have and the removal would never propagate. This is
/// the same reasoning `tag_uniqueness.dart` gives for collapsing `tags` onto
/// the lexically lowest id.
///
/// `id` is the primary key, so it is unique and the ordering is a total one:
/// no tie can survive. That matters beyond determinism. Ordering on
/// `created_at` alone leaves ties, and ties here are the norm, not an edge
/// case: the column is epoch MILLISECONDS and the v92 seed writes all of its
/// rows inside a single `strftime('now')` second. Every tied row would survive
/// and the unique index created straight afterwards would abort the whole
/// migration, leaving the database unopenable -- the v148 lesson.
///
/// Both partition columns are NOT NULL, so the inner query covers every row
/// and the bare `rowid NOT IN (...)` cannot sweep away rows it never
/// considered.
const String _collapseDuplicateDiveTypesSql = '''
  DELETE FROM dive_dive_types WHERE rowid NOT IN (
    SELECT rowid FROM (
      SELECT rowid, ROW_NUMBER() OVER (
        PARTITION BY dive_id, dive_type_id
        ORDER BY created_at ASC, id ASC
      ) AS rn FROM dive_dive_types
    ) WHERE rn = 1
  )
''';

Future<bool> _tableExists(DatabaseConnectionUser db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

/// Collapses duplicate junction rows. Idempotent: a no-op on clean data.
Future<void> collapseDuplicateDiveTypes(DatabaseConnectionUser db) async {
  await db.customStatement(_collapseDuplicateDiveTypesSql);
}

/// Asserts the junction uniqueness index exists, deduping first so creating it
/// cannot abort.
///
/// Called from the v178 migration, from `onCreate` (a fresh install never runs
/// onUpgrade, and `createAll()` does not build raw-SQL indexes) and from
/// `beforeOpen` as a backstop. When the index is already present this costs one
/// `sqlite_master` lookup and does no table scans, so the dedupe is paid once
/// rather than on every open.
///
/// Self-guarding on the tables existing so partial migration-test fixture
/// databases pass through unharmed. `dives` is checked as well as the junction
/// itself: `dive_dive_types.dive_id` is a foreign key into it, and with
/// `PRAGMA foreign_keys = ON` any DML on a table whose FK parent is absent
/// fails with `no such table: main.dives`. The v92 seed guards on the same
/// table for the same reason -- a minimal fixture gets the junction from
/// `createTable` without ever having `dives`.
Future<void> assertDiveTypeUniqueness(DatabaseConnectionUser db) async {
  if (!await _tableExists(db, 'dive_dive_types')) return;
  if (!await _tableExists(db, 'dives')) return;

  // Compare the stored DDL, not just the index NAME. `CREATE UNIQUE INDEX IF
  // NOT EXISTS` is a no-op against an index of the same name whatever its
  // definition, so a name-only check would silently keep an older keying --
  // which is exactly what a database that ran a pre-release build of this
  // version holds. Dropping and rebuilding is cheap next to a wrong index.
  final rows = await db
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: const [Variable<String>(kDiveDiveTypesUniqueIndexName)],
      )
      .get();
  final actual = rows.isEmpty ? null : rows.first.readNullable<String>('sql');
  final expected = kCreateDiveDiveTypesUniqueIndexSql.replaceAll(
    'IF NOT EXISTS ',
    '',
  );
  if (actual != null && _normalizeSql(actual) == _normalizeSql(expected)) {
    return;
  }

  await db.customStatement(
    'DROP INDEX IF EXISTS $kDiveDiveTypesUniqueIndexName',
  );
  await collapseDuplicateDiveTypes(db);
  await db.customStatement(kCreateDiveDiveTypesUniqueIndexSql);
}

/// Collapses whitespace and case so two spellings of the same DDL compare
/// equal. SQLite stores `sqlite_master.sql` as written, so the comparison has
/// to tolerate formatting rather than demand a byte match.
String _normalizeSql(String sql) =>
    sql.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
