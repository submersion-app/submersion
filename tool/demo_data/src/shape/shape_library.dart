import 'dart:math';

import 'dive_shape.dart';

/// Hands out harvested shapes to planned dives.
///
/// A shape fits a dive when it has every wanted kind, the same dive mode,
/// and a maximum depth the reshaper can reach (within its 0.85 to 1.15
/// depth scale). No shape is used more than [maxUses] times in the logbook,
/// and a trip repeats a shape only when its kind has run out of new ones
/// (rebreather dives, for which real data is scarce).
class ShapeLibrary {
  /// Shapes longer than [maxDurationSec] once their surface tail is cut off
  /// come from a source with a broken time scale and are left out.
  ShapeLibrary(List<DiveShape> shapes, this.random)
    : _shapes = [
        for (final s in shapes)
          if (s.withoutSurfaceTail() case final t
              when t.durationSec <= maxDurationSec)
            t,
      ]..sort((a, b) => a.id.compareTo(b.id));

  static const maxUses = 3;

  /// Five hours: longer than any dive in the story.
  static const maxDurationSec = 5 * 3600;

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
        : _byTrip[tripId] ?? const <String>{};
    bool underCap(DiveShape s) => (_uses[s.id] ?? 0) < maxUses;
    bool fits(DiveShape s) =>
        s.maxDepth >= targetMaxDepth / 1.15 &&
        s.maxDepth <= targetMaxDepth / 0.85;
    final ofMode = _shapes
        .where((s) => s.diveMode == diveMode && underCap(s))
        .toList();
    final ofKind = ofMode.where((s) => s.kinds.containsAll(kinds)).toList();
    final newOnTrip = ofKind.where((s) => !usedOnTrip.contains(s.id)).toList();

    // Preferred to least preferred: fits the depth and is new on this trip;
    // new on this trip; any of the kind (a scarce kind may repeat on a
    // trip); any of the dive mode.
    final fitting = newOnTrip.where(fits).toList();
    final DiveShape chosen;
    if (fitting.isNotEmpty) {
      chosen = fitting[random.nextInt(fitting.length)];
    } else {
      final pool = newOnTrip.isNotEmpty
          ? newOnTrip
          : ofKind.isNotEmpty
          ? ofKind
          : ofMode;
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
