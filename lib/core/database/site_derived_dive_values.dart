import 'package:drift/drift.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/database/table_columns.dart';

// The dive values that come from its site (v389, issue #5040).
//
// A site's altitude and water type are properties of the place: a dive reads
// them through (`Dive.effectiveAltitude`, `Dive.effectiveWaterType`) and its
// own columns hold only a value of its own. Linking a site used to copy both
// onto the dive once, so a value the site gained or corrected later never
// reached the dives already made there. Entry and exit methods stay the
// dive's own (a site lists the possible ones, a dive the one used), so an
// empty one is filled from a site that is unambiguous, as linking it does.
//
// Both run from the rung over the whole library, and again after each
// inbound sync apply over the dives it touched: a peer below v389 still
// copies on link, and a sync store written before it still holds the
// copies. Neither moves the sync stamp (`updated_at`, `hlc`): every device
// makes the same change, so they agree without a sync round, and the
// dive's effective values are unchanged by either.
//
// Neither column needs an entry in `changeLogRewrittenColumns`. A revert
// that puts back a cleared copy puts back the site's value as it was then,
// which the dive reads anyway; a filled method only fills an empty one. A
// `dives` entry there would also refuse restoring every stamped dive deleted
// before v389.
//
// Raw SQL, as the other ladder helpers, so it keeps compiling against any
// later shape of the generated classes, guarded on the columns it reads for
// migration fixtures that build only part of the schema.

/// Clears a dive's `altitude` and `water_type` where they equal its site's,
/// and returns how many dives it changed. [diveIds] limits it to the dives
/// named; null sweeps the whole library.
///
/// A value equal to the site's is taken as the copy a link made. A diver who
/// typed the site's own value loses nothing: the dive reads the same value
/// from the site. One that differs is the dive's own and is kept.
Future<int> clearSiteCopiedDiveValues(
  DatabaseConnectionUser db, {
  Iterable<String>? diveIds,
}) async {
  if (!await _hasColumns(db, const {'altitude', 'water_type'})) return 0;
  return _scoped(diveIds, (ids) {
    final scope = _scopeClause(ids);
    return db.customUpdate(
      'UPDATE dives SET '
      'altitude = CASE WHEN altitude = $_siteAltitude THEN NULL '
      'ELSE altitude END, '
      'water_type = CASE WHEN water_type = $_siteWaterType THEN NULL '
      'ELSE water_type END '
      'WHERE site_id IS NOT NULL AND ('
      'altitude = $_siteAltitude OR water_type = $_siteWaterType)$scope',
      variables: _variables(ids),
    );
  });
}

/// Fills a dive's empty `entry_method` and `exit_method` from its site, by
/// the rules linking a site applies (`entryExitAfterSiteAssign`), and
/// returns how many dives it changed. [diveIds] limits it to the dives
/// named; null sweeps the whole library.
///
/// A site contributes a method only when it lists exactly one (issue
/// #2054). An empty exit takes the site's single exit, else follows an
/// entry this fill gave the dive while the site lists at most one exit. A
/// value the dive has is never replaced.
Future<int> fillDiveEntryExitFromSites(
  DatabaseConnectionUser db, {
  Iterable<String>? diveIds,
}) async {
  if (!await _hasColumns(db, const {'entry_method', 'exit_method'})) return 0;
  final siteEntry = _soleSiteMethod('entry_method');
  final siteExit = _soleSiteMethod('exit_method');
  // The entry an empty exit follows: one this fill gives the dive, from a
  // site that lists no more than one exit.
  final followed =
      'CASE WHEN entry_method IS NULL AND (SELECT instr(COALESCE('
      "fs.exit_method, ''), ',') = 0 FROM dive_sites fs "
      'WHERE fs.id = dives.site_id) THEN $siteEntry END';
  return _scoped(diveIds, (ids) {
    final scope = _scopeClause(ids);
    return db.customUpdate(
      'UPDATE dives SET '
      'entry_method = COALESCE(entry_method, $siteEntry), '
      'exit_method = COALESCE(exit_method, $siteExit, $followed) '
      'WHERE site_id IS NOT NULL AND ('
      '(entry_method IS NULL AND $siteEntry IS NOT NULL) OR '
      '(exit_method IS NULL AND COALESCE($siteExit, $followed) IS NOT NULL)'
      ')$scope',
      variables: _variables(ids),
    );
  });
}

const _siteAltitude =
    '(SELECT sa.altitude FROM dive_sites sa WHERE sa.id = dives.site_id)';

const _siteWaterType =
    "(SELECT NULLIF(sw.water_type, '') FROM dive_sites sw "
    'WHERE sw.id = dives.site_id)';

/// The site's [column] when it lists exactly one method this version knows,
/// else NULL. Methods are stored comma-joined.
String _soleSiteMethod(String column) {
  final known = EntryMethod.values.map((m) => "'${m.name}'").join(', ');
  return '(SELECT TRIM(sm.$column) FROM dive_sites sm '
      'WHERE sm.id = dives.site_id '
      "AND instr(sm.$column, ',') = 0 AND TRIM(sm.$column) IN ($known))";
}

Future<bool> _hasColumns(
  DatabaseConnectionUser db,
  Set<String> diveColumns,
) async {
  final dives = await tableColumnNames(db, 'dives');
  final sites = await tableColumnNames(db, 'dive_sites');
  return dives.containsAll({'site_id', ...diveColumns}) &&
      sites.containsAll({'id', ...diveColumns});
}

const _idChunk = 500;

/// Runs [update] over the whole library when [diveIds] is null, else over
/// [diveIds] in chunks well below SQLite's bound-variable limit: one sync
/// payload can carry a whole library.
Future<int> _scoped(
  Iterable<String>? diveIds,
  Future<int> Function(List<String>? ids) update,
) async {
  if (diveIds == null) return update(null);
  final ids = diveIds.toSet().toList();
  var changed = 0;
  for (var i = 0; i < ids.length; i += _idChunk) {
    final end = i + _idChunk < ids.length ? i + _idChunk : ids.length;
    changed += await update(ids.sublist(i, end));
  }
  return changed;
}

String _scopeClause(List<String>? ids) => ids == null
    ? ''
    : ' AND id IN (${List.filled(ids.length, '?').join(', ')})';

List<Variable<Object>> _variables(List<String>? ids) => [
  if (ids != null)
    for (final id in ids) Variable<String>(id),
];
