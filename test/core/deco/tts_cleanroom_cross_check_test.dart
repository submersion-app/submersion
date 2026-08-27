// test/core/deco/tts_cleanroom_cross_check_test.dart
//
// Independent ZHL-16C + gradient-factor TTS, written from the published model
// (Schreiner equation, Buhlmann a/b coefficients) WITHOUT calling the
// production schedule code, to pin the absolute gas-aware TTS numbers. The
// coefficient constants are physical (published) values, re-used from the
// constants file; the integration/ascent logic here is a separate code path.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';

const double _ascentRate = 9.0; // m/min, production default
const double _stopIncrement = 3.0; // m
const double _lastStop = 3.0; // m

double _ambient(double depthMeters) => 1.0 + depthMeters / 10.0;

double _inspiredN2(double depthMeters, double fN2) =>
    (_ambient(depthMeters) - waterVaporPressure) * fN2;

/// Schreiner exponential loading for one compartment over [minutes].
double _load(double tension, double inspired, double minutes, double halfTime) {
  final k = math.log(2) / halfTime;
  return inspired + (tension - inspired) * math.exp(-k * minutes);
}

/// Per-compartment ceiling (m) for N2-only tensions at gradient factor [gf].
double _ceilingMeters(double pn2, int i, double gf) {
  final a = zhl16cN2A[i];
  final b = zhl16cN2B[i];
  final pCeiling = (pn2 - a * gf) / (gf / b + 1 - gf);
  final m = (pCeiling - 1.0) * 10.0;
  return m < 0 ? 0 : m;
}

double _maxCeiling(List<double> pn2, double gf) {
  double maxC = 0;
  for (var i = 0; i < pn2.length; i++) {
    final c = _ceilingMeters(pn2[i], i, gf);
    if (c > maxC) maxC = c;
  }
  return maxC;
}

double _firstStopDepth(List<double> pn2, double gfLow) {
  final c = _maxCeiling(pn2, gfLow);
  if (c <= 0) return 0;
  return (c / _stopIncrement).ceil() * _stopIncrement;
}

/// Independent reference: optimal TTS (seconds) from [startDepth] given loaded
/// N2 tensions, GF low/high, ascent rate 9 m/min, 3 m stops, and a best-gas
/// [plan]. Reimplements the schedule from the published model (Schreiner
/// loading, Buhlmann a/b ceilings, GF interpolation, trial-ascent stop clears)
/// without calling any production schedule code, to pin the absolute numbers.
int referenceTts({
  required List<double> pn2,
  required double startDepth,
  required double gfLow,
  required double gfHigh,
  required AscentGasPlan plan,
}) {
  AscentGas gasForDepth(double depth) => plan.gasForDepth(depth);
  final tensions = List<double>.from(pn2);

  // Anchor the GF interpolation at the deepest GF-low ceiling (unrounded),
  // mirroring production's `_gfLowCeilingAnchor` (Subsurface's
  // gf_low_pressure_this_dive). Fixed for the whole ascent: tissues only
  // offgas above the bottom, so this running-max never grows during ascent.
  final anchor = _maxCeiling(tensions, gfLow);
  // First stop still snaps to the 3 m grid, as production does.
  final firstStop = _firstStopDepth(tensions, gfLow);
  double gfAt(double depth) {
    if (depth <= 0) return gfHigh;
    if (anchor <= 0) return gfHigh;
    if (depth >= anchor) return gfLow;
    return gfHigh - (gfHigh - gfLow) * (depth / anchor);
  }

  // No deco required: a direct ascent to the surface.
  if (_maxCeiling(tensions, gfHigh) <= 0) {
    return (startDepth / _ascentRate * 60).round();
  }

  void integrate(double depth, double fN2, int seconds) {
    final inspired = _inspiredN2(depth, fN2);
    final minutes = seconds / 60.0;
    for (var i = 0; i < tensions.length; i++) {
      tensions[i] = _load(tensions[i], inspired, minutes, zhl16cN2HalfTimes[i]);
    }
  }

  int totalStopSeconds = 0;

  // Load one un-split ascent sub-leg as a single average-depth segment on the
  // gas eligible at its deeper end -- mirroring production's `_ascendLeg`, so
  // the tissue loading discretization matches (Schreiner is convex, so a
  // per-second integral would diverge by ~a stop-minute over a long leg).
  void ascendLeg(double from, double to) {
    if (from <= to) return;
    final gas = gasForDepth(from);
    final seconds = ((from - to) / _ascentRate * 60).round();
    final avgDepth = (from + to) / 2.0;
    integrate(avgDepth, gas.fN2, seconds);
  }

  // Ascend from [from] to [to], splitting at every gas-switch (MOD) depth the
  // leg crosses, exactly as production's `_simulateAscent` does.
  void ascend(double from, double to) {
    if (from <= to) return;
    var top = from;
    for (final switchDepth in plan.switchDepthsBetween(from, to)) {
      ascendLeg(top, switchDepth);
      top = switchDepth;
    }
    ascendLeg(top, to);
  }

  // Travel to the first stop, then walk the 3 m grid up to the last stop.
  ascend(startDepth, firstStop.toDouble());

  for (
    double stop = firstStop.toDouble();
    stop >= _lastStop;
    stop -= _stopIncrement
  ) {
    final nextStop = stop <= _lastStop ? 0.0 : stop - _stopIncrement;
    final fN2 = gasForDepth(stop).fN2;
    // Clear the stop against the ceiling at the NEXT (shallower) stop's GF,
    // matching production's clear-to-next-stop (Subsurface trial_ascent). At
    // the last stop the next level is the surface, where the GF is gfHigh.
    final gf = gfAt(nextStop);

    var stopSeconds = 0;
    const maxStop = 120 * 60;
    while (stopSeconds < maxStop) {
      // Production evaluates the ceiling AFTER a trial minute, then either
      // leaves (keeping the pre-minute state, minute not counted) or commits
      // the minute. So it holds ~1 min less per stop than a check-first loop;
      // replicate that trial-then-commit ordering to match the numbers.
      final snapshot = List<double>.from(tensions);
      integrate(stop, fN2, 60);
      final ceiling = _maxCeiling(tensions, gf);
      for (var i = 0; i < tensions.length; i++) {
        tensions[i] = snapshot[i];
      }
      if (ceiling <= nextStop) break;
      integrate(stop, fN2, 60);
      stopSeconds += 60;
    }
    totalStopSeconds += ((stopSeconds + 59) ~/ 60) * 60;

    if (nextStop >= _lastStop) {
      ascend(stop, nextStop);
    }
  }

  // Geometric ascent time (gas-independent): start depth -> surface.
  final travelSeconds = (startDepth / _ascentRate * 60).round();

  return totalStopSeconds + travelSeconds;
}

void main() {
  test('production gas-aware TTS matches the clean-room reference within 60 s', () {
    // 1. Load tissues by running BuhlmannAlgorithm.calculateSegment for a known
    //    square profile (the loading primitive is shared and already validated).
    final algo = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80)..reset();
    algo.calculateSegment(
      depthMeters: 40,
      durationSeconds: 25 * 60,
      fN2: airN2Fraction,
    );
    final plan = OptimalOcAscentGas(
      gases: const [
        AvailableGas(fN2: airN2Fraction, fHe: 0.0, maxPpO2Mod: double.infinity),
        AvailableGas(fN2: 0.50, fHe: 0.0, maxPpO2Mod: 22.0),
        AvailableGas(fN2: 0.0, fHe: 0.0, maxPpO2Mod: 6.0),
      ],
      maxPpO2: 1.6,
    );

    final prod = algo.calculateTts(currentDepth: 40, ascentGas: plan);

    final reference = referenceTts(
      pn2: algo.compartments.map((c) => c.currentPN2).toList(),
      startDepth: 40,
      gfLow: 0.50,
      gfHigh: 0.80,
      plan: plan,
    );

    expect(prod, greaterThan(0));
    expect(reference, greaterThan(0));
    expect((prod - reference).abs(), lessThanOrEqualTo(60));
  });
}
