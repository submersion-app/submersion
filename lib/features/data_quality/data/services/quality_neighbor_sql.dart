import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/equipment/data/repositories/dive_gear_usage_sql.dart';

/// Dive [other] starts within [window] milliseconds of dive [dive], inclusive.
///
/// Spelled as a range on [other]'s start, not `ABS(a - b) <= window`, so it
/// seeks idx_dives_diver_start or idx_dives_start rather than comparing
/// [dive] with every other dive (issue #3863). Those are expression indexes:
/// the start has to stay [diveStartMillisSql] for SQLite to match them.
String _startsWithinSql(String other, String dive, String window) {
  final start = diveStartMillisSql(dive);
  return '${diveStartMillisSql(other)} BETWEEN $start - $window '
      'AND $start + $window';
}

/// Dives with another dive of the same diver scope inside the window, which
/// is bound as ?1.
///
/// `IS` (not `=`) is intentional: unassigned dives (diver_id NULL) all belong
/// to the implicit default diver -- the same scope `getAllDives(null)` and
/// `DiveMatcher` use -- so both-NULL must match. `IS` still keeps a null-diver
/// dive from pairing across into a specific diver's dives. Do not switch to
/// `=`: it drops the common single-diver (all-NULL) library.
final String qualityPairWindowSql =
    'SELECT DISTINCT a.id AS id FROM dives a JOIN dives b ON a.id != b.id '
    'AND a.diver_id IS b.diver_id '
    'AND ${_startsWithinSql('b', 'a', '?1')}';

/// The neighbors of [idCount] requested dives, which are bound in order. They
/// are in the requested dives' diver scope (see [qualityPairWindowSql] for why
/// that is `IS`) and within [windowMs] of one of them.
String qualityExpandNeighborsSql(int idCount, int windowMs) {
  final placeholders = List.filled(idCount, '?').join(',');
  return 'SELECT DISTINCT b.id AS id FROM dives a JOIN dives b '
      'ON b.id != a.id AND a.diver_id IS b.diver_id '
      'AND ${_startsWithinSql('b', 'a', '$windowMs')} '
      'WHERE a.id IN ($placeholders)';
}

/// Dives sharing an item with another profile's dive inside the window, which
/// is bound as ?1 (issue #2853). Dive pairs first, then shared gear per pair,
/// so each gear branch filters through its dive_id index instead of joining
/// every gear row in the library with every other.
String qualitySharedGearWindowSql() =>
    'SELECT DISTINCT da.id AS id FROM dives da '
    'JOIN dives db ON db.id != da.id '
    'AND da.diver_id IS NOT NULL AND db.diver_id IS NOT NULL '
    'AND da.diver_id != db.diver_id '
    'AND ${_startsWithinSql('db', 'da', '?1')} '
    'WHERE EXISTS (SELECT 1 FROM '
    '(${diveGearUsageSql(diveIdPredicate: '= da.id')}) ga '
    'JOIN (${diveGearUsageSql(diveIdPredicate: '= db.id')}) gb '
    'ON gb.equipment_id = ga.equipment_id)';
