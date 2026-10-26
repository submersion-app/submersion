import 'dart:math';

import 'dive_shape.dart';

/// Hands out harvested shapes to planned dives.
///
/// A shape fits a dive when it has every wanted kind, the same dive mode,
/// and a maximum depth the reshaper can reach (within its 0.85 to 1.15
/// depth scale). No shape is used more than [maxUses] times in the logbook
/// or twice on one trip, so the demo never shows the same dive twice in a
/// row.
class ShapeLibrary {
  ShapeLibrary(List<DiveShape> shapes, this.random)
    : _shapes = [...shapes]..sort((a, b) => a.id.compareTo(b.id));

  static const maxUses = 3;

  final List<DiveShape> _shapes;
  final Random random;
  final _uses = <String, int>{};
  final _byTrip = <String, Set<String>>{};

  DiveShape pick({
    required Set<ShapeKind> kinds,
    required String diveMode,
    required double targetMaxDepth,
    String? tripId,
  }) {
    final usedOnTrip = tripId == null
        ? const <String>{}
        : _byTrip[tripId] ?? {};
    bool free(DiveShape s) =>
        (_uses[s.id] ?? 0) < maxUses && !usedOnTrip.contains(s.id);
    final ofMode = _shapes.where((s) => s.diveMode == diveMode && free(s));
    final ofKind = ofMode.where((s) => s.kinds.containsAll(kinds)).toList();
    final fitting = ofKind
        .where(
          (s) =>
              s.maxDepth >= targetMaxDepth / 1.15 &&
              s.maxDepth <= targetMaxDepth / 0.85,
        )
        .toList();

    final DiveShape chosen;
    if (fitting.isNotEmpty) {
      chosen = fitting[random.nextInt(fitting.length)];
    } else {
      final pool = ofKind.isNotEmpty ? ofKind : ofMode.toList();
      if (pool.isEmpty) {
        throw StateError('no $diveMode shape left for $kinds');
      }
      pool.sort(
        (a, b) => (a.maxDepth - targetMaxDepth).abs().compareTo(
          (b.maxDepth - targetMaxDepth).abs(),
        ),
      );
      chosen = pool.first;
    }
    _uses[chosen.id] = (_uses[chosen.id] ?? 0) + 1;
    if (tripId != null) _byTrip.putIfAbsent(tripId, () => {}).add(chosen.id);
    return chosen;
  }
}
