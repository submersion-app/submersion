import 'package:submersion/core/profile/tank_pressure_glitches.dart';

/// How far back a reading is compared to judge whether a cylinder is falling,
/// in seconds. A rate over this window ignores slow change: a cylinder cooling
/// at 0.5 bar a minute never reads as falling.
const int kBreathLagSeconds = 90;

/// Bar lost over [kBreathLagSeconds] that counts as falling: about 1.3 bar a
/// minute, which a 7 L bottle or a single 12 L cylinder exceeds at a 6 m stop.
const double kBreathFallingBar = 2.0;

/// Seconds of not falling that make a hold, and that end a turn.
const int kBreathHoldSeconds = 120;

/// Net bar a turn must lose. Opening a valve at depth drops the reading 2 or 3
/// bar as the hose fills, and a dip that recovers nets nothing.
const double kBreathNetLossBar = 5.0;

/// Seconds a turn must keep falling. Cooling decays and stops within minutes;
/// breathing carries on.
const int kBreathMinFallingSeconds = 240;

/// A start is the first reading at least this far below the reading the fall
/// was measured from, in bar.
const double kBreathStartOffsetBar = 0.5;

/// The longest silence before a start that still locates it, in seconds.
const int kBreathMaxGapSeconds = 60;

/// The seconds at which a cylinder went from holding to falling, in time
/// order, from its recorded [readings] (issue #4089).
///
/// Each result is the start of a turn on the cylinder after a hold, so the
/// cylinder a dive began on gives none, and a sidemount rotation gives one per
/// turn. Pass recorded transmitter readings only: an estimated series is built
/// partly from the dive's gas switches, so a start found in one would hand the
/// diver's own switch back to them as evidence.
///
/// The thresholds were checked against real breathing, with the results in
/// `docs/design/specs/2026-11-01-gas-switch-time-entry-design.md`.
List<int> cylinderBreathStarts(List<PressureReading> readings) {
  final series = withoutPressureGlitches(readingsInTimeOrder(readings));
  if (series.length < 2) return const [];

  final starts = <int>[];
  var restSince = series.first.t;
  var lastFalling = series.first.t;
  var lag = 0;

  var inTurn = false;
  var level = 0.0;
  var onset = 0;
  var eligible = false;

  void closeTurn(double endBar) {
    if (eligible &&
        level - endBar >= kBreathNetLossBar &&
        lastFalling - onset >= kBreathMinFallingSeconds) {
      starts.add(onset);
    }
    inTurn = false;
  }

  for (var i = 1; i < series.length; i++) {
    final (:t, :bar) = series[i];
    while (lag + 1 < i && series[lag + 1].t <= t - kBreathLagSeconds) {
      lag++;
    }
    final anchor = series[lag];

    if (anchor.bar - bar >= kBreathFallingBar) {
      if (!inTurn) {
        var first = lag + 1;
        while (first < i &&
            series[first].bar > anchor.bar - kBreathStartOffsetBar) {
          first++;
        }
        inTurn = true;
        level = anchor.bar;
        onset = series[first].t;
        eligible =
            onset - restSince >= kBreathHoldSeconds &&
            onset - series[first - 1].t <= kBreathMaxGapSeconds;
      }
      lastFalling = t;
    } else if (inTurn && t - lastFalling >= kBreathHoldSeconds) {
      closeTurn(bar);
      restSince = lastFalling;
    }
  }
  if (inTurn) closeTurn(series.last.bar);

  return starts;
}
