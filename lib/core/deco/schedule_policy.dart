/// Air-break policy for long oxygen stops: after [o2Seconds] on a pure-O2
/// stop gas, breathe the break gas for [breakSeconds], then repeat.
class AirBreakPolicy {
  const AirBreakPolicy({this.o2Seconds = 20 * 60, this.breakSeconds = 5 * 60});

  final int o2Seconds;
  final int breakSeconds;
}

/// How a decompression schedule is generated, independent of the tissue
/// model. Defaults reproduce the engine's legacy behavior.
class SchedulePolicy {
  const SchedulePolicy({
    this.stopIncrement = 3.0,
    this.lastStopDepth = 3.0,
    this.ascentRate = 9.0,
    this.descentRate = 18.0,
    this.ascentRateBands,
    this.gasSwitchStopSeconds = 0,
    this.airBreaks,
  });

  /// Deco stop depth increment in meters.
  final double stopIncrement;

  /// Shallowest deco stop depth in meters (3 or 6).
  final double lastStopDepth;

  /// Ascent rate in meters per minute (used when [ascentRateBands] is null).
  final double ascentRate;

  /// Descent rate in meters per minute.
  final double descentRate;

  /// Optional per-depth-band ascent rates (Subsurface's four bands), ordered
  /// `[belowMean75, mean75to50, mean50to6, last6m]` in m/min. Null = use the
  /// single [ascentRate] everywhere (legacy behavior).
  final List<double>? ascentRateBands;

  /// Minimum time in seconds to hold at a stop where the breathed gas
  /// changes (0 = no minimum).
  final int gasSwitchStopSeconds;

  /// Optional O2 air-break policy; null = no air breaks.
  final AirBreakPolicy? airBreaks;

  /// The ascent rate that applies at [depthMeters], given the plan's
  /// [meanDepthMeters]. Bands split at 75% and 50% of mean depth and at 6 m.
  double ascentRateForDepth(double depthMeters, double meanDepthMeters) {
    final bands = ascentRateBands;
    if (bands == null || bands.length != 4) return ascentRate;
    if (depthMeters <= 6) return bands[3];
    if (depthMeters <= meanDepthMeters * 0.5) return bands[2];
    if (depthMeters <= meanDepthMeters * 0.75) return bands[1];
    return bands[0];
  }
}
