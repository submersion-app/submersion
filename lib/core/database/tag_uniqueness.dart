/// Tag identity invariants: one `tags` row per (diver scope, name) and one
/// `dive_tags` row per (dive, tag) -- issue #1032.
///
/// Two independent producers used to put the same tag on a dive more than
/// once, and neither table constrained them:
///
///  * `tags` has a uuid primary key minted per device and no index on `name`,
///    so a peer's row for a tag the user already had landed beside it. Two
///    devices that each ran a dive-computer import minted two uuids for the
///    same auto-generated `<Computer> Import <date>` name.
///  * `dive_tags` has a surrogate uuid primary key, so re-running an import
///    (or any blind re-link) added a second row for a pair that already
///    existed.
///
/// Both are now unique indexes. Every writer must therefore be conflict-safe:
/// with an index in place an unguarded duplicate insert THROWS, and a throw
/// inside the sync merge is far worse than the duplicate it replaces.
library;

import 'package:drift/drift.dart';

/// Unique index over `tags`, keyed on (diver scope, case-folded name).
const String kTagsUniqueIndexName = 'idx_tags_diver_name_unique';

/// Unique index over the `dive_tags` junction, keyed on (dive, tag).
const String kDiveTagsUniqueIndexName = 'idx_dive_tags_dive_tag_unique';

/// `diver_id` is NULLABLE, and SQLite treats NULLs as distinct inside a unique
/// index, so a plain `(diver_id, name)` index would not constrain the
/// unassigned-diver rows at all -- exactly the rows an importer creates before
/// a diver is resolved. `COALESCE(diver_id, '')` folds NULL into a single
/// "unassigned" scope so those rows are constrained too.
///
/// `lower(trim(name))` is the full normalization, and every lookup and writer
/// applies exactly the same one, so the index cannot disagree with the read
/// that decides whether to create a tag. `trim` is load-bearing rather than
/// cosmetic: matching on a trimmed name while storing the untrimmed one let
/// " Wreck" and "Wreck" exist as two rows that every lookup treats as one --
/// the duplicate this index exists to forbid (PR #1033 review). All three
/// functions are deterministic, which SQLite requires of an expression
/// index.
///
/// Two divers keep their own identically named tags, and an unassigned tag
/// stays distinct from a diver-scoped one of the same name: those are
/// different scopes, not duplicates.
const String kCreateTagsUniqueIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kTagsUniqueIndexName '
    "ON tags(COALESCE(diver_id, ''), lower(trim(name)))";

/// One junction row per (dive, tag). The surrogate `id` stays the primary key
/// so a re-inserted row never collides with the tombstone of the row it
/// replaced (the composite-key sync data-loss trap of #347).
const String kCreateDiveTagsUniqueIndexSql =
    'CREATE UNIQUE INDEX IF NOT EXISTS $kDiveTagsUniqueIndexName '
    'ON dive_tags(dive_id, tag_id)';

/// Strips surrounding whitespace from stored tag names.
///
/// The index keys on `lower(trim(name))`, so a stored " Wreck" and a stored
/// "Wreck" already collapse to one slot -- but only one of them can survive,
/// and the survivor should not keep whitespace the user never intended and
/// cannot see. Running this first also means the rows a user reads back match
/// the value every lookup compares against.
const String _normalizeTagNamesSql =
    'UPDATE tags SET name = trim(name) WHERE name <> trim(name)';

/// Repoints every `dive_tags` row at the surviving tag of its group.
///
/// The survivor is the lexically lowest `id` in the group. It has to be a
/// property of the rows themselves rather than of this device (oldest
/// `created_at` ties inside a single import millisecond, and "the one we had
/// first" differs per device), so every device that runs this -- or the
/// equivalent merge-time reconciliation -- lands on the same tag.
///
/// The `WHERE EXISTS` guard matters: `dive_tags.tag_id` is NOT NULL, and a row
/// pointing at an already-missing tag would otherwise resolve to NULL and
/// abort the statement.
const String _repointDiveTagsToSurvivorSql = '''
  UPDATE dive_tags SET tag_id = (
    SELECT MIN(survivor.id) FROM tags survivor, tags mine
    WHERE mine.id = dive_tags.tag_id
      AND COALESCE(survivor.diver_id, '') = COALESCE(mine.diver_id, '')
      AND lower(trim(survivor.name)) = lower(trim(mine.name))
  )
  WHERE EXISTS (SELECT 1 FROM tags t WHERE t.id = dive_tags.tag_id)
''';

const String _deleteLosingTagsSql = '''
  DELETE FROM tags WHERE id NOT IN (
    SELECT MIN(id) FROM tags GROUP BY COALESCE(diver_id, ''), lower(trim(name))
  )
''';

/// Keeps one junction row per (dive, tag). `rowid` is a total order, so this
/// can never leave a tie behind -- a tie-blind cleanup keyed on `created_at`
/// would, and the unique index created straight afterwards would then abort
/// the whole migration and leave the database unopenable.
const String _collapseDuplicateDiveTagsSql = '''
  DELETE FROM dive_tags WHERE rowid NOT IN (
    SELECT MIN(rowid) FROM dive_tags GROUP BY dive_id, tag_id
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

/// Collapses duplicate tags and duplicate junction rows, in the only order
/// that leaves no ties: normalize the names the grouping keys on, repoint the
/// junctions at the surviving tag, drop the losing tags, then collapse the
/// junction duplicates the repoint just created.
///
/// Idempotent: every statement is a no-op on already-clean data.
Future<void> collapseDuplicateTags(DatabaseConnectionUser db) async {
  await db.customStatement(_normalizeTagNamesSql);
  await db.customStatement(_repointDiveTagsToSurvivorSql);
  await db.customStatement(_deleteLosingTagsSql);
  await db.customStatement(_collapseDuplicateDiveTagsSql);
}

/// Asserts the two uniqueness indexes exist, deduping first so creating them
/// cannot abort.
///
/// Called from the v149 migration, from `onCreate` (a fresh install never runs
/// onUpgrade, and `createAll()` does not build raw-SQL indexes) and from
/// `beforeOpen` as a backstop. When both indexes are already present this
/// costs one `sqlite_master` lookup and does no table scans, so the dedupe is
/// paid once rather than on every open.
///
/// Self-guarding on the tables existing so partial migration-test fixture
/// databases pass through unharmed.
Future<void> assertTagUniqueness(DatabaseConnectionUser db) async {
  if (!await _tableExists(db, 'tags')) return;
  if (!await _tableExists(db, 'dive_tags')) return;

  // Compare the stored DDL, not just the index NAME. `CREATE UNIQUE INDEX IF
  // NOT EXISTS` is a no-op against an index of the same name whatever its
  // definition, so a name-only check would silently keep an older keying --
  // which is exactly what a database that ran a pre-release build of this
  // version holds. Dropping and rebuilding is cheap next to a wrong index.
  final present = {
    for (final row
        in await db
            .customSelect(
              "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
              'AND name IN (?, ?)',
              variables: const [
                Variable<String>(kTagsUniqueIndexName),
                Variable<String>(kDiveTagsUniqueIndexName),
              ],
            )
            .get())
      row.read<String>('name'): row.readNullable<String>('sql') ?? '',
  };

  bool matches(String name, String expectedSql) {
    final actual = present[name];
    if (actual == null) return false;
    return _normalizeSql(actual) ==
        _normalizeSql(expectedSql.replaceAll('IF NOT EXISTS ', ''));
  }

  final tagsOk = matches(kTagsUniqueIndexName, kCreateTagsUniqueIndexSql);
  final junctionOk = matches(
    kDiveTagsUniqueIndexName,
    kCreateDiveTagsUniqueIndexSql,
  );
  if (tagsOk && junctionOk) return;

  if (!tagsOk) {
    await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
  }
  if (!junctionOk) {
    await db.customStatement('DROP INDEX IF EXISTS $kDiveTagsUniqueIndexName');
  }

  await collapseDuplicateTags(db);
  await db.customStatement(kCreateTagsUniqueIndexSql);
  await db.customStatement(kCreateDiveTagsUniqueIndexSql);
}

/// Collapses whitespace and case so two spellings of the same DDL compare
/// equal. SQLite stores `sqlite_master.sql` as written, so the comparison has
/// to tolerate formatting rather than demand a byte match.
String _normalizeSql(String sql) =>
    sql.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
