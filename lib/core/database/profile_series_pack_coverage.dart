/// Coverage: "is this legacy row already represented by a series row", and
/// everything that asks it.
///
/// Split from `profile_series_pack.dart` to keep that file under the
/// project's 800-line limit. The pack, the scan that decides which dives it
/// visits, and the residue count that gates dropping a legacy table all
/// have to answer that question the same way, so the predicate and its
/// callers live together.
library;

import 'package:drift/drift.dart';

/// Legacy rows still waiting to be packed, per legacy table.
typedef LegacyPackResidue = ({int profiles, int tanks});

/// How many rows each legacy table still holds that the pack should have
/// moved into the series tables and did not.
///
/// This is the gate on dropping a legacy table. [packLegacyProfileRows]
/// never deletes what it packs, so "is the legacy table empty" cannot be
/// the question; the question is whether a series row now covers every
/// legacy row that could ever become one. Three reachable ways the pack
/// leaves a row behind while returning normally, all of which this counts:
/// a pressure row whose tank is gone is skipped as an orphan; a dive that
/// already had a series row is never revisited, so a second computer's
/// legacy rows are never packed; and every insert is `INSERT OR IGNORE`, so
/// a series table shaped differently by a parallel branch can pack nothing
/// at all.
///
/// Coverage is checked per (dive, computer) for profiles and per (dive,
/// tank, computer) for tanks, resolving a dangling computer id to null the
/// way the packer's own grouping does. Finer identity terms (`source_id`,
/// `is_primary`) are deliberately left out: the pack works per dive, so
/// partialness below the computer level can only come from an ignored
/// insert, and gating on it would keep a table for a difference no read
/// ever sees.
///
/// A row that can NEVER be packed does not count, or the table would be
/// kept forever and its pages never reclaimed: a row with no READABLE
/// timestamp, depth, or pressure holds no sample, and a row whose dive is
/// gone could never have been rendered. A row whose tank is gone DOES
/// count: the dive is still the diver's, and those bytes are the only copy
/// left.
Future<LegacyPackResidue> countLegacyRowsAwaitingPack(
  DatabaseConnectionUser db, {
  String profileTable = 'dive_profiles',
  String tankTable = 'tank_pressure_profiles',
}) async => (
  profiles: await _countUnpackedProfileRows(db, profileTable),
  tanks: await _countUnpackedTankRows(db, tankTable),
);

Future<int> _countUnpackedProfileRows(
  DatabaseConnectionUser db,
  String table,
) async {
  final columns = await legacyColumnNames(db, table);
  if (columns.isEmpty) return 0;
  // A shape the packer cannot read, a missing series table, or a missing
  // `dives` table all mean nothing moved: every row is still only here.
  if (!columns.containsAll(const {'dive_id', 'timestamp', 'depth'}) ||
      !await legacyTableExists(db, 'dive_profile_series') ||
      !await legacyTableExists(db, 'dives')) {
    return _countRows(db, table);
  }
  final covered = await legacyRowCoveredSql(
    db,
    legacyTable: table,
    seriesTable: 'dive_profile_series',
    byTank: false,
  );
  // Grouped before the correlated predicate, for the reason
  // [legacyCoverageIdentityColumns] documents.
  final identity = (await legacyCoverageIdentityColumns(
    db,
    legacyTable: table,
    byTank: false,
  )).join(', ');
  final rows = await db
      .customSelect(
        'SELECT COALESCE(SUM(p.n), 0) AS n FROM '
        '(SELECT $identity, COUNT(*) AS n FROM $table '
        'WHERE ${readableNumberSql('timestamp')} AND ${readableNumberSql('depth')} '
        'GROUP BY $identity) p '
        'WHERE EXISTS (SELECT 1 FROM dives d WHERE d.id = p.dive_id) '
        'AND NOT $covered',
      )
      .getSingle();
  return rows.read<int>('n');
}

Future<int> _countUnpackedTankRows(
  DatabaseConnectionUser db,
  String table,
) async {
  final columns = await legacyColumnNames(db, table);
  if (columns.isEmpty) return 0;
  if (!columns.containsAll(const {
        'dive_id',
        'tank_id',
        'timestamp',
        'pressure',
      }) ||
      !await legacyTableExists(db, 'tank_pressure_series') ||
      !await legacyTableExists(db, 'dives')) {
    return _countRows(db, table);
  }
  final covered = await legacyRowCoveredSql(
    db,
    legacyTable: table,
    seriesTable: 'tank_pressure_series',
    byTank: true,
  );
  final identity = (await legacyCoverageIdentityColumns(
    db,
    legacyTable: table,
    byTank: true,
  )).join(', ');
  final rows = await db
      .customSelect(
        'SELECT COALESCE(SUM(p.n), 0) AS n FROM '
        '(SELECT $identity, COUNT(*) AS n FROM $table '
        'WHERE ${readableNumberSql('timestamp')} '
        'AND ${readableNumberSql('pressure')} '
        "AND ${readableTextSql('tank_id')} GROUP BY $identity) p "
        'WHERE EXISTS (SELECT 1 FROM dives d WHERE d.id = p.dive_id) '
        'AND NOT $covered',
      )
      .getSingle();
  return rows.read<int>('n');
}

/// The columns [legacyRowCoveredSql] reads off the legacy row, so a caller
/// can collapse the table to one row per identity before evaluating it.
///
/// The predicate is a correlated subquery: evaluated per legacy ROW it costs
/// an index seek per sample, which on a million-sample table is the whole
/// per-open cost of the backstop. Evaluated per identity it costs one seek
/// per group, which is what the scan and the residue count both claim.
Future<List<String>> legacyCoverageIdentityColumns(
  DatabaseConnectionUser db, {
  required String legacyTable,
  required bool byTank,
  bool byGroupIdentity = false,
}) async {
  final columns = await legacyColumnNames(db, legacyTable);
  return [
    'dive_id',
    if (byTank) 'tank_id',
    if (columns.contains('computer_id')) 'computer_id',
    if (byGroupIdentity && !byTank) ...[
      if (columns.contains('source_id')) 'source_id',
      if (columns.contains('is_primary')) 'is_primary',
    ],
  ];
}

/// SQL predicate: the legacy row aliased `p` is already represented by a
/// row of [seriesTable].
///
/// Identity, not dive. A dive can be half packed: this device holds a series
/// for one computer while a peer below v183 still publishes row-per-sample
/// rows for the same dive from two. Asking "does this dive have a series"
/// would call the second computer's rows done and, on the staging path where
/// the staged rows are the only copy, discard them.
///
/// The identity is `(dive, computer)` for profiles and `(dive, tank,
/// computer)` for pressures, resolving a dangling computer id to null the
/// way the packer's own grouping does. Finer terms (`source_id`,
/// `is_primary`) are deliberately left out, matching what gates dropping a
/// legacy table: a difference below the computer level can only come from an
/// ignored insert, and acting on it would pack a second series for an
/// identity a read already resolves.
Future<String> legacyRowCoveredSql(
  DatabaseConnectionUser db, {
  required String legacyTable,
  required String seriesTable,
  required bool byTank,
  bool byGroupIdentity = false,
}) async {
  final columns = await legacyColumnNames(db, legacyTable);
  // A legacy row that names no computer matches a series whatever computer
  // the series carries, but ONLY on the identity-grained (staging) path.
  // This device stamps a computer onto its own series after packing
  // (consolidation's stampComputerWhereNull, relinkComputer,
  // adoptUnattributed), while a peer below the floor still holds the same
  // readings unattributed: an exact match would find nothing and pack the
  // peer's copy a second time, and nothing collapses duplicate series on
  // read. A staged row that DOES name a computer is a different source and
  // still has to match exactly.
  final computerMatch = 's.computer_id IS ${await resolvedComputerSql(db)}';
  final computer = columns.contains('computer_id')
      ? byGroupIdentity
            ? 'AND (p.computer_id IS NULL OR $computerMatch)'
            : 'AND $computerMatch'
      : '';
  final tank = byTank ? 'AND s.tank_id = p.tank_id' : '';
  var group = '';
  if (byGroupIdentity && !byTank) {
    // The two terms the packer groups on below the computer level. A
    // pressure row has neither, so byTank needs nothing extra. source_id
    // takes the same null-is-a-wildcard rule as computer_id, for the same
    // reason (adoptUnattributed moves it from NULL to a source).
    final sourceMatch = 's.source_id IS ${await resolvedSourceSql(db)}';
    final primary = columns.contains('is_primary') ? _primarySql : '1';
    group =
        'AND (p.source_id IS NULL OR $sourceMatch) '
        'AND s.is_primary = $primary';
  }
  return 'EXISTS (SELECT 1 FROM $seriesTable s '
      'WHERE s.dive_id = p.dive_id $tank $computer $group)';
}

/// The legacy `is_primary` value as the 0 or 1 a series row stores, spelled
/// to agree with the packer's `_boolOf` on EVERY value.
///
/// A plain `CASE WHEN p.is_primary` disagrees with it twice, and each
/// disagreement leaves the staged rows undrained forever while the packer
/// re-runs over them on every sync apply: SQLite sends a NULL to the ELSE
/// and reads it as demoted, where `_boolOf` reads an absent flag as the
/// dive's live profile; and it applies its own text-to-numeric rule, so a
/// peer's `"isPrimary": "yes"`, which INTEGER affinity leaves as text, reads
/// as demoted where `_boolOf` reads any non-num as primary. Testing
/// `typeof` first confines SQLite's truthiness to the numeric values both
/// sides agree on. Change this and `_boolOf` together.
const String _primarySql =
    'CASE WHEN p.is_primary IS NULL THEN 1 '
    "WHEN typeof(p.is_primary) IN ('integer', 'real') "
    'THEN (CASE WHEN p.is_primary THEN 1 ELSE 0 END) ELSE 1 END';

/// [resolvedComputerSql]'s twin for `source_id`.
Future<String> resolvedSourceSql(DatabaseConnectionUser db) async =>
    await legacyTableExists(db, 'dive_data_sources')
    ? '(SELECT ds.id FROM dive_data_sources ds WHERE ds.id = p.source_id)'
    : 'NULL';

/// The scalar subquery that mirrors [_resolvedParent] for `computer_id`: the
/// legacy row's computer when it still names a `dive_computers` row, null
/// otherwise. Null too when the parent table itself is gone, which is what
/// the packer's empty parent set resolves every id to.
Future<String> resolvedComputerSql(DatabaseConnectionUser db) async =>
    await legacyTableExists(db, 'dive_computers')
    ? '(SELECT c.id FROM dive_computers c WHERE c.id = p.computer_id)'
    : 'NULL';

/// SQL for "[column] holds a number the packer can read", the predicate
/// half of `profileSampleOf`'s `is! num` test.
///
/// `IS NOT NULL` is not the same question. SQLite carries a storage class
/// per value, so a REAL-affinity column can hold text it could not convert;
/// that row is not null but holds no sample, the packer steps over it, and
/// counting it as awaiting pack would keep the legacy table and its pages
/// forever waiting for a pack that can never claim it.
///
/// Also the guard on READING such a column as a number. Drift's `read<int>`
/// converts rather than casts, but converting is `int.parse`, so numeric
/// text passes and anything else throws a [FormatException]. Any query that
/// reads a legacy numeric column has to filter on this first.
String readableNumberSql(String column) =>
    "typeof($column) IN ('integer', 'real')";

/// SQL for "[column] holds text", the guard on reading a legacy id column
/// with `read<String>`. See [readableNumberSql] for why a declared type is
/// not enough on these tables.
String readableTextSql(String column) => "typeof($column) = 'text'";

Future<int> _countRows(DatabaseConnectionUser db, String table) async {
  final rows = await db
      .customSelect('SELECT COUNT(*) AS n FROM $table')
      .getSingle();
  return rows.read<int>('n');
}

Future<bool> legacyTableExists(DatabaseConnectionUser db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(table)],
      )
      .get();
  return rows.isNotEmpty;
}

/// The column names of [table], empty when the table does not exist.
Future<Set<String>> legacyColumnNames(
  DatabaseConnectionUser db,
  String table,
) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return {for (final row in rows) row.read<String>('name')};
}
