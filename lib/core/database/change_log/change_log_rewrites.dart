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

/// For a column in [changeLogRewrittenColumns] whose rung rewrote only the
/// values it found out of shape, the test for such a value.
///
/// A logged value the rung would have left alone means the same now, so a
/// revert may still put it back: a dive rated 4 stars and deleted before v358
/// can be restored. A value the test flags is refused whenever it was
/// logged, because an inbound sync apply runs the same repair after the rung
/// and can log the value it replaced. A column listed only in
/// [changeLogRewrittenColumns] refuses every value logged before its rung.
const Map<String, bool Function(Object? value)> changeLogRewrittenValues = {
  'dives.rating': _ratingOutOfScale,
};

bool _ratingOutOfScale(Object? value) {
  final rating = switch (value) {
    final num n => n.toInt(),
    final String s => num.tryParse(s)?.toInt(),
    _ => null,
  };
  return rating != null && DiveRatingScale.normalize(rating) != rating;
}

/// Whether a revert must refuse [value], logged for [table].[column] at
/// [schemaVersion], because a rung has since rewritten what it means.
bool changeLogValueRewritten(
  Map<String, int> rewrittenColumns,
  String table,
  String column,
  int schemaVersion,
  Object? value,
) {
  final key = '$table.$column';
  final rewrittenAt = rewrittenColumns[key];
  if (rewrittenAt == null) return false;
  final outOfShape = changeLogRewrittenValues[key];
  if (outOfShape != null) return outOfShape(value);
  return schemaVersion < rewrittenAt;
}
