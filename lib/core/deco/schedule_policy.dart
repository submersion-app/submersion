/// Air-break policy for long oxygen stops: after [o2Seconds] on a pure-O2
/// stop gas, breathe the break gas for [breakSeconds], then repeat.
class AirBreakPolicy {
  const AirBreakPolicy({this.o2Seconds = 20 * 60, this.breakSeconds = 5 * 60});

  final int o2Seconds;
  final int breakSeconds;
}

/// Which phase of the ascent a travel leg belongs to.
///
/// The rates a diver is taught are named after the phase, not the depth: the
/// leg off the bottom is a working ascent whether the first stop is at 21 m or
/// 6 m, and the leg off the last stop is the slow one whether or not anything
/// deeper was required. Only [betweenStops] needs a depth, to tell an
/// intermediate stop from a shallow one.
enum AscentPhase {
  /// Bottom to the first decompression stop - or, on a dive that owes
  /// nothing, straight to the surface. A no-deco ascent is this phase and
  /// only this phase: none of the slower deco rates apply to it.
  toFirstStop,

  /// Between two decompression stops.
  betweenStops,

  /// The last decompression stop to the surface.
  fromLastStop;

  /// The phase of a leg that lands on the surface, given the phase the walk
  /// over the stops has reached.
  ///
  /// Off the last stop once any stop has actually been held; still the
  /// working ascent when none was, because a dive that owes nothing never
  /// leaves the [toFirstStop] leg it started on.
  static AscentPhase surfacingAfter(AscentPhase walked) =>
      walked == AscentPhase.toFirstStop
      ? AscentPhase.toFirstStop
      : AscentPhase.fromLastStop;
}

/// How a decompression schedule is generated, independent of the tissue
/// model. Defaults reproduce the engine's legacy behavior.
class SchedulePolicy {
  const SchedulePolicy({
    this.stopIncrement = 3.0,
    this.lastStopDepth = 3.0,
    this.shallowStopDepth = 9.0,
    this.ascentRate = 9.0,
    double? intermediateAscentRate,
    double? shallowAscentRate,
    double? finalAscentRate,
    this.descentRate = 18.0,
    this.gasSwitchStopSeconds = 0,
    this.snapStopsToWholeMinutes = false,
    this.airBreaks,
  }) : intermediateAscentRate = intermediateAscentRate ?? ascentRate,
       shallowAscentRate = shallowAscentRate ?? ascentRate,
       finalAscentRate = finalAscentRate ?? ascentRate;

  /// Deco stop depth increment in meters.
  final double stopIncrement;

  /// Shallowest deco stop depth in meters (3 or 6).
  final double lastStopDepth;

  /// Depth in meters below which a decompression stop counts as *shallow*,
  /// switching travel between stops from [intermediateAscentRate] to
  /// [shallowAscentRate].
  ///
  /// 9 m by convention: the 9/6/3 stops are the shallow ones. Not a plan
  /// setting, because the standards that name these phases do not
  /// parameterise the boundary either.
  final double shallowStopDepth;

  /// Working ascent rate in meters per minute: bottom to the first stop, and
  /// the whole ascent on a dive that owes no decompression.
  final double ascentRate;

  /// Ascent rate in meters per minute between intermediate stops - those
  /// deeper than [shallowStopDepth].
  ///
  /// Defaults to [ascentRate], so a caller that knows about only one rate
  /// keeps its previous behaviour exactly. That is what keeps the dive log,
  /// profile analysis and VPM-B unaffected: only the planner sets the phases
  /// apart.
  final double intermediateAscentRate;

  /// Ascent rate in meters per minute between shallow stops - those at or
  /// above [shallowStopDepth]. Defaults to [ascentRate].
  final double shallowAscentRate;

  /// Ascent rate in meters per minute from the last stop to the surface.
  ///
  /// The shallowest metres are where a given depth change costs the most
  /// pressure change, so this is conventionally the slowest. Applies only
  /// when there was a last stop to leave; see [AscentPhase.toFirstStop].
  /// Defaults to [ascentRate].
  final double finalAscentRate;

  /// Descent rate in meters per minute.
  final double descentRate;

  /// Minimum time in seconds to hold at a stop where the breathed gas
  /// changes (0 = no minimum).
  final int gasSwitchStopSeconds;

  /// Extend each stop so it ends on a whole minute of the ascent clock.
  ///
  /// Travel between stops rarely takes a whole number of minutes (3 m at
  /// 6 m/min is thirty seconds), so without this every stop would start and
  /// end at odd seconds and a slate could not be read against a watch. With
  /// it, the stop absorbs the odd seconds of the leg that led to it - at most
  /// 59 s more at each stop, always in the conservative direction - and the
  /// schedule reads as whole minutes from the first stop on. Subsurface does
  /// the same (its first stop chunk is sized to land the clock on a minute).
  ///
  /// Off by default so live decompression numbers in the dive log and on the
  /// profile keep their exact values; the planner turns it on.
  final bool snapStopsToWholeMinutes;

  /// Optional O2 air-break policy; null = no air breaks.
  final AirBreakPolicy? airBreaks;

  /// The rate in meters per minute for a leg of [phase] starting at
  /// [fromDepth].
  double ascentRateFor(AscentPhase phase, {double fromDepth = 0}) =>
      switch (phase) {
        AscentPhase.toFirstStop => ascentRate,
        AscentPhase.betweenStops =>
          fromDepth > shallowStopDepth
              ? intermediateAscentRate
              : shallowAscentRate,
        AscentPhase.fromLastStop => finalAscentRate,
      };

  /// Seconds to ascend from [fromDepth] to [toDepth] during [phase].
  ///
  /// Returns 0 for a level or descending leg, which lets callers hand over
  /// whatever pair of depths they have without guarding first.
  int ascentSeconds({
    required double fromDepth,
    required double toDepth,
    AscentPhase phase = AscentPhase.toFirstStop,
  }) {
    if (fromDepth <= toDepth) return 0;
    final rate = ascentRateFor(phase, fromDepth: fromDepth);
    if (rate <= 0) return 0;
    return ((fromDepth - toDepth) / rate * 60).round();
  }

  /// Total seconds spent *travelling* on an ascent from [fromDepth] that
  /// pauses at each of [stopDepths] (deepest first) and finishes at the
  /// surface. Excludes the time held at the stops themselves.
  ///
  /// Assigns the phases the way a schedule runs: down to the first stop, then
  /// between stops, then off the last stop. With no stops at all the whole
  /// ascent is one [AscentPhase.toFirstStop] leg. Callers that need the legs
  /// individually - to sample the profile, or to charge gas against the right
  /// cylinder - walk the same sequence, which this mirrors so a total can
  /// never disagree with the legs it is made of.
  int ascentTravelSeconds({
    required double fromDepth,
    required Iterable<double> stopDepths,
  }) {
    var seconds = 0;
    var depth = fromDepth;
    var phase = AscentPhase.toFirstStop;
    for (final stop in stopDepths) {
      seconds += ascentSeconds(fromDepth: depth, toDepth: stop, phase: phase);
      depth = stop;
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      seconds += ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
    }
    return seconds;
  }
}
