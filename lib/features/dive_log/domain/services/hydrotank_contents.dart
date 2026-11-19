import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// An Avelo Hydrotank's estimated contents at one moment (issue #4664), as
/// fractions of the tank from the bottom: [water] is the top of the water,
/// [gasLeft] the top of the gas still left (the rest of the tank above it
/// is the share of the gas space already breathed).
typedef HydrotankContents = ({double water, double gasLeft});

/// The Hydrotank's contents when its pressure is [nowBar] and the computer
/// reports [gasRemainingPercent], for a dive that started at [startBar].
///
/// Assumes the tank held no water at the start: the gas then fills the
/// whole tank at [startBar], so with [gasRemainingPercent] of that gas left
/// at [nowBar] it fills `(startBar / nowBar) x gasRemainingPercent` of the
/// tank, and water is the rest, clamped to the tank. Gas left is the gas
/// space shaded by gas remaining. An estimate for the figure only: nothing
/// else reads it.
///
/// Null without a positive pressure to work from.
HydrotankContents? hydrotankContents({
  required double startBar,
  required double nowBar,
  required int gasRemainingPercent,
}) {
  if (startBar <= 0 || nowBar <= 0) return null;
  final remaining = (gasRemainingPercent / 100).clamp(0.0, 1.0);
  final gasSpace = (startBar / nowBar * remaining).clamp(0.0, 1.0);
  final water = 1.0 - gasSpace;
  return (water: water, gasLeft: water + gasSpace * remaining);
}

/// The Hydrotank gas remaining the figure reads (issue #4664): with no
/// [seconds], the last value logged below the surface (the end of the dive,
/// as the Avelo summary reads it); at [seconds], the last value logged at or
/// before that time. Null when there is none.
int? gasRemainingAt(List<DiveProfilePoint> profile, int? seconds) {
  // The profile is time-ordered (the series codec enforces it), so the
  // cursor's sample is found by binary search: this runs on every cursor
  // frame.
  var end = profile.length;
  if (seconds != null) {
    var low = 0;
    while (low < end) {
      final mid = (low + end) >> 1;
      if (profile[mid].timestamp <= seconds) {
        low = mid + 1;
      } else {
        end = mid;
      }
    }
  }
  for (var i = end - 1; i >= 0; i--) {
    final p = profile[i];
    if (p.aveloGasRemaining == null) continue;
    if (seconds == null && p.depth <= 0) continue;
    return p.aveloGasRemaining;
  }
  return null;
}
