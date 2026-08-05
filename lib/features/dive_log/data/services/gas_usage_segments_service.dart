import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// One contiguous period during a dive when a single gas mix was breathed.
///
/// Drives the gas-usage timeline strip rendered below the dive profile.
/// Times are in seconds from dive start; [endSeconds] is exclusive.
class GasUsageSegment {
  final int startSeconds;
  final int endSeconds;
  final GasMix gasMix;
  final String label;
  final String? tankName;

  const GasUsageSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.gasMix,
    required this.label,
    this.tankName,
  });

  int get durationSeconds => endSeconds - startSeconds;
}

/// Builds gas-usage segments for the dive profile gas-timeline strip.
///
/// Algorithm:
/// 1. Pick the starting tank (lowest [DiveTank.order], or the first tank).
/// 2. Sort gas switches by timestamp and clamp to dive bounds.
/// 3. A switch at or before [firstSampleSeconds] is the dive's initial-gas
///    declaration rather than a mid-dive switch, and owns the window from t=0.
/// 4. Otherwise the initial segment runs from t=0 to the first switch, filled
///    from the starting tank.
/// 5. Each subsequent segment runs from one switch to the next, ending at
///    [diveDurationSeconds] for the final switch.
/// 6. Adjacent segments with identical gas mixes are merged so a switch back
///    to the same gas does not produce a visible seam.
///
/// [firstSampleSeconds] is the timestamp of the dive's first profile sample.
/// Dive computers do not sample at t=0, and importers record the starting gas
/// as a gas-change event at that first sample; without it a phantom leading
/// segment is invented from the lowest-order tank, which renders a sliver of
/// the wrong gas whenever that tank holds a different mix (issue #679).
///
/// Returns an empty list when there are no tanks or the dive has no
/// duration — the caller should hide the strip in that case.
List<GasUsageSegment> buildGasUsageSegments({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> gasSwitches,
  required int diveDurationSeconds,
  int firstSampleSeconds = 0,
}) {
  if (tanks.isEmpty || diveDurationSeconds <= 0) {
    return const <GasUsageSegment>[];
  }

  final tankById = {for (final t in tanks) t.id: t};
  final startingTank = ([
    ...tanks,
  ]..sort((a, b) => a.order.compareTo(b.order))).first;

  final inBoundsSwitches =
      ([...gasSwitches]..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
          .where((s) => s.timestamp >= 0 && s.timestamp <= diveDurationSeconds)
          .toList(growable: false);

  if (inBoundsSwitches.isEmpty) {
    return [
      GasUsageSegment(
        startSeconds: 0,
        endSeconds: diveDurationSeconds,
        gasMix: startingTank.gasMix,
        label: startingTank.gasMix.name,
        tankName: startingTank.name,
      ),
    ];
  }

  final segments = <GasUsageSegment>[];

  final initialIndex = _initialGasDeclarationIndex(
    inBoundsSwitches,
    firstSampleSeconds,
  );

  if (initialIndex == null) {
    segments.add(
      GasUsageSegment(
        startSeconds: 0,
        endSeconds: inBoundsSwitches.first.timestamp,
        gasMix: startingTank.gasMix,
        label: startingTank.gasMix.name,
        tankName: startingTank.name,
      ),
    );
  }

  for (var i = initialIndex ?? 0; i < inBoundsSwitches.length; i++) {
    final cur = inBoundsSwitches[i];
    final startSec = i == initialIndex ? 0 : cur.timestamp;
    final endSec = i + 1 < inBoundsSwitches.length
        ? inBoundsSwitches[i + 1].timestamp
        : diveDurationSeconds;
    if (startSec >= endSec) continue;
    final tank = tankById[cur.tankId];
    final gasMix = GasMix(o2: cur.o2Fraction * 100, he: cur.heFraction * 100);
    segments.add(
      GasUsageSegment(
        startSeconds: startSec,
        endSeconds: endSec,
        gasMix: gasMix,
        label: gasMix.name,
        tankName: tank?.name,
      ),
    );
  }

  return _mergeAdjacentSameGas(segments);
}

/// Index into [sorted] of the switch that declares the dive's starting gas, or
/// null when the first switch is a genuine mid-dive change.
///
/// Importers write the starting gas as a gas-change event at the first profile
/// sample, so any switch at or before [firstSampleSeconds] is a declaration,
/// not a change. When several land in that window the last one wins — it is the
/// gas actually carried into the dive.
int? _initialGasDeclarationIndex(
  List<GasSwitchWithTank> sorted,
  int firstSampleSeconds,
) {
  int? index;
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i].timestamp > firstSampleSeconds) break;
    index = i;
  }
  return index;
}

List<GasUsageSegment> _mergeAdjacentSameGas(List<GasUsageSegment> segments) {
  if (segments.length < 2) return segments;
  final merged = <GasUsageSegment>[segments.first];
  for (var i = 1; i < segments.length; i++) {
    final last = merged.last;
    final cur = segments[i];
    final sameGas =
        last.gasMix.o2 == cur.gasMix.o2 && last.gasMix.he == cur.gasMix.he;
    if (sameGas && last.endSeconds == cur.startSeconds) {
      merged[merged.length - 1] = GasUsageSegment(
        startSeconds: last.startSeconds,
        endSeconds: cur.endSeconds,
        gasMix: last.gasMix,
        label: last.label,
        tankName: last.tankName,
      );
    } else {
      merged.add(cur);
    }
  }
  return merged;
}

/// Per-tank active intervals: for each tankId, the ascending, non-overlapping
/// [start, end) windows during which it was the breathed gas.
///
/// Uses the same starting-tank + switch-walk rules as [buildGasUsageSegments]
/// (starting tank = lowest [DiveTank.order]; switches sorted and clamped to
/// [0, diveDurationSeconds]; a switch at or before [firstSampleSeconds] is the
/// initial-gas declaration and owns the window from t=0, otherwise that window
/// goes to the starting tank), but keys by tankId with no gas-mix merging.
///
/// Returns an empty map when there are no tanks or the dive has no duration.
Map<String, List<({int start, int end})>> buildActiveTankIntervals({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> gasSwitches,
  required int diveDurationSeconds,
  int firstSampleSeconds = 0,
}) {
  final result = <String, List<({int start, int end})>>{};
  if (tanks.isEmpty || diveDurationSeconds <= 0) return result;

  final startingTank = ([
    ...tanks,
  ]..sort((a, b) => a.order.compareTo(b.order))).first;

  final inBounds =
      ([...gasSwitches]..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
          .where((s) => s.timestamp >= 0 && s.timestamp <= diveDurationSeconds)
          .toList(growable: false);

  void add(String tankId, int start, int end) {
    if (start >= end) return;
    result.putIfAbsent(tankId, () => []).add((start: start, end: end));
  }

  if (inBounds.isEmpty) {
    add(startingTank.id, 0, diveDurationSeconds);
    return result;
  }

  final initialIndex = _initialGasDeclarationIndex(
    inBounds,
    firstSampleSeconds,
  );

  if (initialIndex == null) {
    add(startingTank.id, 0, inBounds.first.timestamp);
  }
  for (var i = initialIndex ?? 0; i < inBounds.length; i++) {
    final end = i + 1 < inBounds.length
        ? inBounds[i + 1].timestamp
        : diveDurationSeconds;
    add(inBounds[i].tankId, i == initialIndex ? 0 : inBounds[i].timestamp, end);
  }
  return result;
}
