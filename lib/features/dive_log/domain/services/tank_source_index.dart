/// Sentinel for a dive_tanks.source_tank_index that takes no parsed tank: the
/// row a series reassignment left behind. Re-parse never matches it, so the
/// row stays a pressureless cylinder instead of re-acquiring its old series.
const int kNoSourceTankIndex = -1;

/// The parsed tank index a row's computer-owned data comes from.
///
/// Rows written before v200 carry null; those with a pressure series were
/// keyed on tank order by the old re-parse path, and those without one own no
/// parsed tank at all.
int effectiveSourceTankIndex({
  required int? sourceTankIndex,
  required int tankOrder,
  required bool hasSeries,
}) {
  if (sourceTankIndex != null) return sourceTankIndex;
  return hasSeries ? tankOrder : kNoSourceTankIndex;
}
