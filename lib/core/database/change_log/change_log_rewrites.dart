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
  'dives.rating': 358,
};
