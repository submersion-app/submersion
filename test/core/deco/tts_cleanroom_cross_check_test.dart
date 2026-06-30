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
/// selector. Integrates ascent and stops in 1-second steps; loads each tissue
/// with the Schreiner equation on the gas eligible at the current depth.
int referenceTts({
  required List<double> pn2,
  required double startDepth,
  required double gfLow,
  required double gfHigh,
  required AscentGas Function(double depth) gasForDepth,
}) {
  final tensions = List<double>.from(pn2);

  // Anchor the GF interpolation at the initial first-stop depth.
  final firstStop = _firstStopDepth(tensions, gfLow);
  double gfAt(double depth) {
    if (depth <= 0) return gfHigh;
    if (firstStop <= 0) return gfHigh;
    if (depth >= firstStop) return gfLow;
    return gfHigh - (gfHigh - gfLow) * (depth / firstStop);
  }

  // No deco required: a direct ascent to the surface.
  if (_maxCeiling(tensions, gfHigh) <= 0) {
    return (startDepth / _ascentRate * 60).round();
  }

  const stepSeconds = 1;

  void integrate(double depth, double fN2, int seconds) {
    final inspired = _inspiredN2(depth, fN2);
    final minutes = seconds / 60.0;
    for (var i = 0; i < tensions.length; i++) {
      tensions[i] = _load(tensions[i], inspired, minutes, zhl16cN2HalfTimes[i]);
    }
  }

  int totalStopSeconds = 0;

  // Ascend from [from] to [to] at the fixed rate, integrating per second on
  // the gas eligible at the (descending) current depth.
  void ascend(double from, double to) {
    if (from <= to) return;
    final totalSeconds = ((from - to) / _ascentRate * 60).round();
    var depth = from;
    final perStep = (from - to) / totalSeconds;
    for (var s = 0; s < totalSeconds; s++) {
      final midDepth = depth - perStep / 2.0;
      integrate(midDepth, gasForDepth(midDepth).fN2, stepSeconds);
      depth -= perStep;
    }
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
    final gf = gfAt(stop);

    var stopSeconds = 0;
    const maxStop = 120 * 60;
    while (stopSeconds < maxStop) {
      if (_maxCeiling(tensions, gf) <= nextStop) break;
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
      gasForDepth: plan.gasForDepth,
    );

    expect(prod, greaterThan(0));
    expect(reference, greaterThan(0));
    expect((prod - reference).abs(), lessThanOrEqualTo(60));
  });
}
