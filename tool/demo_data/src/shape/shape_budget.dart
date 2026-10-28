import 'dart:math';

import '../story/story_plan.dart';
import 'dive_shape.dart';
import 'shape_library.dart';

/// Planned dives of one kind that the harvested shapes cannot cover without
/// using a shape more than [ShapeLibrary.maxUses] times.
class ShapeShortfall {
  const ShapeShortfall({
    required this.diveMode,
    required this.kinds,
    required this.needed,
    required this.available,
    required this.depthsM,
  });

  final String diveMode;

  /// Every kind the short dives ask for (several when their groups share
  /// shapes).
  final Set<ShapeKind> kinds;
  final int needed;
  final int available;

  /// The (shallowest, deepest) planned depth of the short dives.
  final (double, double) depthsM;

  @override
  String toString() =>
      '$diveMode ${kinds.map((k) => k.name).join('+')} at '
      '${depthsM.$1.round()} to ${depthsM.$2.round()} m: '
      'needs $needed, shapes allow $available';
}

/// The dive kinds of [plan] that [shapes] cannot cover, so the build stops
/// before seeding instead of quietly giving a technical dive a recreational
/// shape (the library's last resort).
///
/// Dives are grouped by dive mode, wanted kinds and planned depth, and a
/// shape fits a group when it has the kinds and the reshaper can take it to
/// that depth ([ShapeLibrary.reaches]), as the picker requires. Groups that
/// can draw on the same shape are judged together: their uses are handed
/// out greedily, the group with the fewest fitting shapes first, and a group
/// left short reports the whole set's demand against the whole set's
/// capacity.
List<ShapeShortfall> shapeShortfalls(
  StoryPlan plan,
  List<DiveShape> shapes, {
  int maxUses = ShapeLibrary.maxUses,
}) {
  final demand = <(String, Set<ShapeKind>, double), int>{};
  final keys = <String, (String, Set<ShapeKind>, double)>{};
  for (final d in plan.dives) {
    final names = [for (final k in d.wantedKinds) k.name]..sort();
    final id = '${d.diveMode}|${names.join(',')}|${d.targetMaxDepth}';
    final key = keys.putIfAbsent(
      id,
      () => (d.diveMode, d.wantedKinds, d.targetMaxDepth),
    );
    demand[key] = (demand[key] ?? 0) + 1;
  }
  final fitting = {
    for (final key in demand.keys)
      key: {
        for (final s in shapes)
          if (s.diveMode == key.$1 &&
              s.kinds.containsAll(key.$2) &&
              ShapeLibrary.reaches(s, key.$3))
            s.id,
      },
  };

  // Groups joined through a shared shape.
  final groups = demand.keys.toList();
  final component = {for (var i = 0; i < groups.length; i++) groups[i]: i};
  int find(int i) {
    while (component[groups[i]] != i) {
      i = component[groups[i]]!;
    }
    return i;
  }

  for (var i = 0; i < groups.length; i++) {
    for (var j = i + 1; j < groups.length; j++) {
      if (fitting[groups[i]]!.intersection(fitting[groups[j]]!).isNotEmpty) {
        component[groups[find(j)]] = find(i);
      }
    }
  }

  final shortfalls = <ShapeShortfall>[];
  final byComponent = <int, List<(String, Set<ShapeKind>, double)>>{};
  for (var i = 0; i < groups.length; i++) {
    byComponent.putIfAbsent(find(i), () => []).add(groups[i]);
  }
  for (final members in byComponent.values) {
    members.sort((a, b) => fitting[a]!.length.compareTo(fitting[b]!.length));
    final left = <String, int>{};
    var short = false;
    for (final g in members) {
      var need = demand[g]!;
      for (final id in fitting[g]!) {
        if (need == 0) break;
        final free = left[id] ?? maxUses;
        final take = free < need ? free : need;
        left[id] = free - take;
        need -= take;
      }
      if (need > 0) short = true;
    }
    if (!short) continue;
    final shapeIds = {for (final g in members) ...fitting[g]!};
    shortfalls.add(
      ShapeShortfall(
        diveMode: members.first.$1,
        kinds: {for (final g in members) ...g.$2},
        needed: members.fold(0, (sum, g) => sum + demand[g]!),
        available: shapeIds.length * maxUses,
        depthsM: (
          members.map((g) => g.$3).reduce(min),
          members.map((g) => g.$3).reduce(max),
        ),
      ),
    );
  }
  return shortfalls;
}
