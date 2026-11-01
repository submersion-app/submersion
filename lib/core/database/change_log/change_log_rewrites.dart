/// Columns a later rung rewrote in place, keyed `'table.column'`, each with
/// the version of that rung (issue #3922).
///
/// A logged value from before the rewrite means something else now (a wall
/// clock shifted, a unit changed, a blob re-encoded), so a revert refuses it
/// and says why. A rung that rewrites stored values adds its column here. It
/// does not have to rewrite the log as well, which would put a permanent cost
/// on every data migration.
const Map<String, int> changeLogRewrittenColumns = {};
