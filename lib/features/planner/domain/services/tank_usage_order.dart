import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// Reorders per-tank usages so they read in the order the schedule actually
/// breathes them: the first cylinder a row charges comes first, the next new
/// one after it, and so on. Cylinders no row ever charges keep their
/// original relative order and follow at the end.
///
/// The cylinder list a diver authors is in whatever order they added the
/// tanks, which is rarely the order the dive uses them; reading the gas list
/// in schedule order lets each line be checked against the table above it
/// without hunting.
List<PlanTankUsage> orderUsagesByFirstUse(
  List<PlanTankUsage> usages,
  List<PlanScheduleRow> rows,
) {
  final rank = <String, int>{};
  for (final row in rows) {
    final id = row.tankId;
    if (id != null && !rank.containsKey(id)) rank[id] = rank.length;
  }
  if (rank.isEmpty) return usages;
  final indexed = usages.indexed.toList()
    ..sort((a, b) {
      final ra = rank[a.$2.tankId] ?? rank.length;
      final rb = rank[b.$2.tankId] ?? rank.length;
      if (ra != rb) return ra.compareTo(rb);
      return a.$1.compareTo(b.$1);
    });
  return [for (final (_, usage) in indexed) usage];
}
