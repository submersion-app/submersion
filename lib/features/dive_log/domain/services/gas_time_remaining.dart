/// Gas Time Remaining (GTR), the way an air-integrated dive computer shows it.
///
/// GTR is the time in minutes a diver can stay at the current depth, at the
/// current surface air consumption, before a direct ascent to the surface at
/// [gtrAscentRateMetersPerMinute] would leave exactly the reserve pressure in
/// the tank. This mirrors Shearwater's definition: SAC is averaged over the
/// trailing [defaultGtrSacWindowSeconds], safety and deco stops are ignored,
/// and the value is blanked whenever a deco ceiling exists.
///
/// The arithmetic is entirely in tank pressure, so cylinder volume never
/// enters it: a diver on any tank size with the same bar/min SAC and the same
/// gauge reading gets the same GTR.
library;

import 'dart:math' as math;

import 'package:submersion/core/utils/time_weighted_mean.dart';

/// Direct-ascent rate the GTR calculation assumes (Shearwater: 10 m/min).
const double gtrAscentRateMetersPerMinute = 10.0;

/// Trailing window the SAC estimate is averaged over (Shearwater: 2 min).
const int defaultGtrSacWindowSeconds = 120;

/// Reserve pressure GTR counts down to when the diver has not set one
/// (bar; Shearwater ships 48 bar / 700 psi, the planner uses 50).
const double defaultGtrReserveBar = 50.0;

/// Depth below which a sample counts as being on the surface.
const double _surfaceDepthMeters = 1.0;

/// Gas time remaining per sample, in seconds; null where the computer would
/// blank the display.
///
/// A sample is blank when:
/// - the diver is on the surface (depth under 1 m),
/// - fewer than [sacWindowSeconds] of pressure history exist yet,
/// - pressure is not falling over the window (SAC is zero or negative), or
/// - [ceilings] reports a deco ceiling above 0 m at that sample.
///
/// [pressures] is the tank pressure track in bar, aligned with [depths] and
/// [timestamps] (seconds). [reserveBar] is the pressure the diver wants to
/// surface with. Once the reserve plus the gas needed for the ascent exceeds
/// the current pressure the value is 0, never negative.
///
/// Depth and pressure are read as piecewise linear series, so the window holds
/// exactly [sacWindowSeconds] of history wherever it opens, and a sample added
/// on an existing segment leaves the result unchanged.
///
/// Seconds are truncated, not rounded: displays floor these to whole minutes,
/// so rounding 2939.8 s up to 2940 would read 49 min for 48 min 59.8 s left,
/// and a countdown must never say there is more gas time than there is.
List<int?> calculateGtrCurve({
  required List<double> depths,
  required List<int> timestamps,
  required List<double> pressures,
  required double reserveBar,
  List<double>? ceilings,
  int sacWindowSeconds = defaultGtrSacWindowSeconds,
}) {
  final n = depths.length;
  if (timestamps.length != n || pressures.length != n) {
    throw ArgumentError(
      'depths (${depths.length}), timestamps (${timestamps.length}) and '
      'pressures (${pressures.length}) must have the same length',
    );
  }
  if (ceilings != null && ceilings.length != n) {
    throw ArgumentError(
      'ceilings (${ceilings.length}) must match depths (${depths.length})',
    );
  }

  final result = List<int?>.filled(n, null);
  // Both window bounds only move forward, so one cursor and a cumulative depth
  // integral keep the whole pass O(n). Re-summing the window per sample instead
  // costs O(n * samples-per-window), which on a densely sampled or merged
  // profile is the entire profile at every sample. The cursor advances on
  // every iteration, including ones the guards below skip, so that it stays in
  // step with the window.
  final depthIntegral = TimeWeightedMean();
  final depthAreaTo = List<double>.filled(n, 0.0);
  var anchor = 0;
  for (var i = 0; i < n; i++) {
    depthIntegral.add(timestamps[i], depths[i]);
    depthAreaTo[i] = depthIntegral.area;
    final windowStart = timestamps[i] - sacWindowSeconds;
    while (anchor + 1 < i && timestamps[anchor + 1] <= windowStart) {
      anchor++;
    }

    final depth = depths[i];
    if (depth < _surfaceDepthMeters) continue;
    if (ceilings != null && ceilings[i] > 0) continue;
    if (timestamps[0] > windowStart) continue;

    final windowOpens = math.max(windowStart, timestamps[anchor]);
    final durationSeconds = timestamps[i] - windowOpens;
    if (durationSeconds <= 0) continue;

    final pressureDrop =
        _readAt(pressures, timestamps, anchor, windowOpens) - pressures[i];
    if (pressureDrop <= 0) continue;

    // The anchor sample can sit before the window, so take off the area
    // between it and where the window opens.
    final depthAtOpen = _readAt(depths, timestamps, anchor, windowOpens);
    final areaBeforeOpen =
        (windowOpens - timestamps[anchor]) * (depths[anchor] + depthAtOpen) / 2;
    final windowArea = depthAreaTo[i] - depthAreaTo[anchor] - areaBeforeOpen;
    final meanDepth = windowArea / durationSeconds;
    final consumptionAtDepth = pressureDrop / (durationSeconds / 60.0);
    final sac = consumptionAtDepth / _ambientBar(meanDepth);
    if (sac <= 0) continue;

    // Gas burned by a direct ascent: SAC times the ascent's duration times
    // the mean ambient pressure of a linear ascent from here to the surface.
    final ascentMinutes = depth / gtrAscentRateMetersPerMinute;
    final ascentGasBar = sac * ascentMinutes * _ambientBar(depth / 2);
    final usableBar = pressures[i] - reserveBar - ascentGasBar;
    if (usableBar <= 0) {
      result[i] = 0;
      continue;
    }
    final minutesAtDepth = usableBar / (sac * _ambientBar(depth));
    result[i] = (minutesAtDepth * 60).floor();
  }
  return result;
}

/// [series] at [time], at or after sample [before] and before the next one.
double _readAt(
  List<double> series,
  List<int> timestamps,
  int before,
  int time,
) {
  final beforeTime = timestamps[before];
  if (time <= beforeTime) return series[before];
  final progress = (time - beforeTime) / (timestamps[before + 1] - beforeTime);
  return series[before] + (series[before + 1] - series[before]) * progress;
}

double _ambientBar(double depthMeters) => 1.0 + depthMeters / 10.0;
