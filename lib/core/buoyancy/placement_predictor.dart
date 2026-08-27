import 'package:submersion/core/buoyancy/weight_observation.dart';

/// Splits a predicted total across weight placements (WeightType.name keys)
/// using the diver's habitual distribution.
class PlacementPredictor {
  /// Returns null when nothing qualifies (no placement history, or a zero
  /// total).
  ///
  /// [exposureItemId] is the planned rig's exposure-suit equipment id;
  /// observations sharing it are preferred (placement habits usually follow
  /// the suit), with a fallback to all placement-bearing observations.
  /// [incrementKg] is the rounding step: 0.5 for metric display, one pound
  /// for imperial. Largest-remainder allocation keeps the parts summing
  /// exactly to the rounded total.
  static Map<String, double>? predict({
    required double totalKg,
    required List<WeightObservation> observations,
    String? exposureItemId,
    required double incrementKg,
    int maxObservations = 10,
  }) {
    if (totalKg <= 0 || incrementKg <= 0) return null;

    var candidates = observations.where((o) => o.placement.isNotEmpty).toList();
    if (candidates.isEmpty) return null;

    if (exposureItemId != null) {
      final matched = candidates
          .where((o) => o.equipmentIds.contains(exposureItemId))
          .toList();
      if (matched.isNotEmpty) candidates = matched;
    }

    candidates.sort((a, b) => b.diveDateTime.compareTo(a.diveDateTime));
    if (candidates.length > maxObservations) {
      candidates = candidates.sublist(0, maxObservations);
    }

    // Average each placement's fraction of its dive's total.
    final fractionSums = <String, double>{};
    var counted = 0;
    for (final observation in candidates) {
      final diveTotal = observation.placement.values.fold(0.0, (a, b) => a + b);
      if (diveTotal <= 0) continue;
      counted++;
      observation.placement.forEach((type, kg) {
        fractionSums.update(
          type,
          (v) => v + kg / diveTotal,
          ifAbsent: () => kg / diveTotal,
        );
      });
    }
    if (counted == 0) return null;

    // Largest-remainder allocation in increment units.
    final totalUnits = (totalKg / incrementKg).round();
    if (totalUnits <= 0) return null;

    final entries = fractionSums.entries
        .map((e) => (type: e.key, raw: (e.value / counted) * totalUnits))
        .toList();
    final floors = {for (final e in entries) e.type: e.raw.floor()};
    var remaining = totalUnits - floors.values.fold(0, (a, b) => a + b);
    entries.sort(
      (a, b) => (b.raw - b.raw.floor()).compareTo(a.raw - a.raw.floor()),
    );
    for (final entry in entries) {
      if (remaining <= 0) break;
      floors[entry.type] = floors[entry.type]! + 1;
      remaining--;
    }

    final placement = <String, double>{
      for (final e in floors.entries)
        if (e.value > 0) e.key: e.value * incrementKg,
    };
    return placement.isEmpty ? null : placement;
  }
}
