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
/// 3. The initial segment runs from t=0 to the first switch's timestamp
///    (skipped if the first switch is exactly at t=0).
/// 4. Each subsequent segment runs from one switch to the next, ending at
///    [diveDurationSeconds] for the final switch.
/// 5. Adjacent segments with identical gas mixes are merged so a switch back
///    to the same gas does not produce a visible seam.
///
/// Returns an empty list when there are no tanks or the dive has no
/// duration — the caller should hide the strip in that case.
List<GasUsageSegment> buildGasUsageSegments({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> gasSwitches,
  required int diveDurationSeconds,
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

  final firstSwitch = inBoundsSwitches.first;
  if (firstSwitch.timestamp > 0) {
    segments.add(
      GasUsageSegment(
        startSeconds: 0,
        endSeconds: firstSwitch.timestamp,
        gasMix: startingTank.gasMix,
        label: startingTank.gasMix.name,
        tankName: startingTank.name,
      ),
    );
  }

  for (var i = 0; i < inBoundsSwitches.length; i++) {
    final cur = inBoundsSwitches[i];
    final endSec = i + 1 < inBoundsSwitches.length
        ? inBoundsSwitches[i + 1].timestamp
        : diveDurationSeconds;
    if (cur.timestamp >= endSec) continue;
    final tank = tankById[cur.tankId];
    final gasMix = GasMix(o2: cur.o2Fraction * 100, he: cur.heFraction * 100);
    segments.add(
      GasUsageSegment(
        startSeconds: cur.timestamp,
        endSeconds: endSec,
        gasMix: gasMix,
        label: gasMix.name,
        tankName: tank?.name,
      ),
    );
  }

  return _mergeAdjacentSameGas(segments);
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
