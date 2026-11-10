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
  // cleared a stored 0 (issue #4415), so a logged rating may be out of scale.
  // Only those values were rewritten: see changeLogRewrittenValues.
  'dives.rating': 358,
};

/// Puts a logged value into the shape a rung has since given its column.
///
/// Returns the value as the rung would have left it, or the value itself
/// when the rung would not have touched it.
typedef ChangeLogValueRepair = Object? Function(Object? value);

/// For a column in [changeLogRewrittenColumns] whose rung rewrote only the
/// values it found out of shape, how it rewrote them.
///
/// The column's version there then only marks it as rewritten: a logged value
/// the repair leaves alone means the same now, whenever it was logged, and a
/// value it changes is out of shape whenever it was logged. So an edit back to
/// a 4-star rating can still be reverted, an edit back to an out-of-scale one
/// is refused, and a deleted dive returns with its rating put on the scale
/// rather than not at all. A column listed only in [changeLogRewrittenColumns]
/// refuses every value logged before its rung.
const Map<String, ChangeLogValueRepair> changeLogRewrittenValues = {
  'dives.rating': _ratingOnScale,
};

Object? _ratingOnScale(Object? value) {
  final rating = switch (value) {
    final num n => n.toInt(),
    final String s => num.tryParse(s)?.toInt(),
    _ => null,
  };
  if (rating == null) return value;
  final stars = DiveRatingScale.normalize(rating);
  return stars == rating ? value : stars;
}

/// Whether reverting [table].[column] to [value], logged at [schemaVersion],
/// must be refused because a rung has since rewritten what it means.
bool changeLogValueRewritten(
  Map<String, int> rewrittenColumns,
  String table,
  String column,
  int schemaVersion,
  Object? value, {
  Map<String, ChangeLogValueRepair> rewrittenValues = changeLogRewrittenValues,
}) {
  final key = '$table.$column';
  final rewrittenAt = rewrittenColumns[key];
  if (rewrittenAt == null) return false;
  final repair = rewrittenValues[key];
  if (repair != null) return repair(value) != value;
  return schemaVersion < rewrittenAt;
}

/// Whether restoring a deleted record must be refused for its logged
/// [table].[column] value. A column whose rung has a repair in
/// [rewrittenValues] never refuses: [changeLogRestoredValue] repairs it.
bool changeLogRestoreBlocked(
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

/// The logged [table].[column] [value] a restore writes back, repaired when
/// [rewrittenColumns] and [rewrittenValues] say a rung reshaped the column.
Object? changeLogRestoredValue(
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
