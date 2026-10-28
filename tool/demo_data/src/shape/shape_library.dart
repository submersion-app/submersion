import 'dart:math';

import 'dive_shape.dart';
import 'reshaper.dart';

/// Hands out harvested shapes to planned dives.
///
/// A shape fits a dive when it has every wanted kind, the same dive mode,
/// and a maximum depth the reshaper can take to the dive's ([reaches]). No
/// shape is used more than [maxUses] times in the logbook,
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

  /// The kinds that say what sort of dive a shape is.
  static const _storyKinds = {
    ShapeKind.recreational,
    ShapeKind.deepOpenCircuit,
    ShapeKind.multiGasDeco,
    ShapeKind.trimix,
    ShapeKind.ccr,
    ShapeKind.scr,
  };

  /// Five hours: longer than any dive in the story.
  static const maxDurationSec = 5 * 3600;

  final List<DiveShape> _shapes;

  /// The shapes the library hands out, after the broken ones are left out.
  List<DiveShape> get shapes => List.unmodifiable(_shapes);
  final Random random;
  final _uses = <String, int>{};
  final _byTrip = <String, Set<String>>{};

  /// Whether the reshaper can take [shape] to [targetMaxDepth], scaling its
  /// depth by up to 1.15 and down to [Reshaper.minDepthScale].
  static bool reaches(DiveShape shape, double targetMaxDepth) =>
      shape.maxDepth >= targetMaxDepth / 1.15 &&
      shape.maxDepth * Reshaper.minDepthScale(shape.diveMode) <= targetMaxDepth;

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
    final ofMode = _shapes
        .where((s) => s.diveMode == diveMode && underCap(s))
        .toList();
    // Among candidates, those carrying the fewest story kinds beyond the
    // wanted ones: a deco dive leaves the scarce deep-and-deco shapes to the
    // dives that need both, as long as it has a shape of its own that
    // reaches its depth.
    int extra(DiveShape s) =>
        s.kinds.difference(kinds).where(_storyKinds.contains).length;
    List<DiveShape> leastExtra(Iterable<DiveShape> shapes) {
      final list = shapes.toList();
      if (list.isEmpty) return list;
      final fewest = list.map(extra).reduce(min);
      return list.where((s) => extra(s) == fewest).toList();
    }

    final withKinds = ofMode.where((s) => s.kinds.containsAll(kinds)).toList();
    if (withKinds.isEmpty && !kinds.contains(ShapeKind.recreational)) {
      throw StateError('no $diveMode shape left for $kinds');
    }
    final ofKind = leastExtra(withKinds);
    final newOnTrip = withKinds
        .where((s) => !usedOnTrip.contains(s.id))
        .toList();

    // Preferred to least preferred: reaches the depth and is new on this
    // trip; new on this trip; any of the kind (a scarce kind may repeat on a
    // trip); any of the dive mode. Reaching the depth comes before carrying
    // no extra kinds.
    final fitting = leastExtra(
      newOnTrip.where((s) => reaches(s, targetMaxDepth)),
    );
    final DiveShape chosen;
    if (fitting.isNotEmpty) {
      chosen = fitting[random.nextInt(fitting.length)];
    } else {
      final newFewest = leastExtra(newOnTrip);
      final pool = newFewest.isNotEmpty
          ? newFewest
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
