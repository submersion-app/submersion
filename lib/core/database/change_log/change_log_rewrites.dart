import 'package:submersion/core/utils/dive_rating_scale.dart';

/// Columns a later rung rewrote in place, keyed `'table.column'`, each with
/// the version of that rung (issue #3922).
///
/// A logged value from before the rewrite means something else now (a wall
/// clock shifted, a unit changed, a blob re-encoded), so a revert refuses it
/// and says why. A rung that rewrites stored values adds its column here. It
/// does not have to rewrite the log as well, which would put a permanent cost
/// on every data migration.
const Map<String, int> changeLogRewrittenColumns = {
  // v336 moved these rows from their trip to a checklist (issue #3356). A
  // delete copy from before it has no checklist_id, which a restore needs.
  'trip_checklist_items.trip_id': 336,
  'trip_checklist_sections.trip_id': 336,
  // v337 turned milliseconds back into the seconds this column holds (issue
  // #4119), so a stamp logged before it may be a thousand times too large.
  'dives.weather_fetched_at': 337,
  // v358 halved a rating a UDDF import stored on the 1 to 10 scale, and
  // cleared a stored 0 (issue #4415). It rewrote only those values, which
  // changeLogRewrittenValues repairs, so 358 is never compared: a logged
  // rating is put on the scale rather than refused, whenever it was logged.
  'dives.rating': 358,
};

/// Puts a logged value into the shape a rung has since given its column.
///
/// Returns the value as the rung would have left it, or the value itself
/// when the rung would not have touched it. Applying it twice changes
/// nothing more.
typedef ChangeLogValueRepair = Object? Function(Object? value);

/// For a column in [changeLogRewrittenColumns] whose rung rewrote only the
/// values it found out of shape, how it rewrote them.
///
/// A logged value of such a column is repaired, never refused: a revert puts
/// back what the logged value means now, and a deleted record returns with it
/// repaired. So an edit from an imported rating of 0 to 3 stars reverts to
/// unrated, and a dive rated 8 before v358 is restored with 4 stars. Every key
/// here must also be in [changeLogRewrittenColumns], which marks the column.
const Map<String, ChangeLogValueRepair> changeLogRewrittenValues = {
  'dives.rating': DiveRatingScale.normalizeStored,
};

/// Whether a revert or restore must refuse a [table].[column] value logged
/// at [schemaVersion], because a rung has since rewritten what it means and
/// [rewrittenValues] has no repair for it.
bool changeLogValueRewritten(
  Map<String, int> rewrittenColumns,
  String table,
  String column,
  int schemaVersion, {
  Map<String, ChangeLogValueRepair> rewrittenValues = changeLogRewrittenValues,
}) {
  final key = '$table.$column';
  final rewrittenAt = rewrittenColumns[key];
  if (rewrittenAt == null || rewrittenValues.containsKey(key)) return false;
  return schemaVersion < rewrittenAt;
}

/// A logged [table].[column] [value] as it reads now: repaired when
/// [rewrittenColumns] and [rewrittenValues] say a rung reshaped the column,
/// and unchanged otherwise.
Object? changeLogRepairedValue(
  Map<String, int> rewrittenColumns,
  String table,
  String column,
  Object? value, {
  Map<String, ChangeLogValueRepair> rewrittenValues = changeLogRewrittenValues,
}) {
  final key = '$table.$column';
  final repair = rewrittenValues[key];
  if (repair == null || !rewrittenColumns.containsKey(key)) return value;
  return repair(value);
}
