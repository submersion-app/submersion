import 'dart:math';

import '../shape/dive_shape.dart';
import '../story/story_plan.dart';

/// The water a dive goes through: warm at the top, colder below a
/// thermocline, and what a dive computer's slow sensor makes of it.
///
/// A harvested shape's own temperatures belong to its source dive's water (a
/// summer lake can span 14 degrees), so the demo dives are given the water
/// of the place and season they are dived in instead.
class WaterColumn {
  const WaterColumn({
    required this.surfaceC,
    required this.deepC,
    required this.thermoclineM,
    required this.widthM,
  });

  /// The water at [destination] on a day planned at [plannedC].
  ///
  /// Where the water [Destination.stratifies] (a lake, the New Jersey
  /// coast), the planned temperature is the deep water, which the summer sun
  /// warms above a sharp thermocline, and winter turns over; elsewhere it is
  /// the water near the top, as divers quote it, colder below. Seas with
  /// seasons cool a few degrees at depth in summer; tropical water is within
  /// a degree or so from top to bottom, and a spring is the same all the way
  /// down.
  factory WaterColumn.forDive(
    Destination destination,
    double plannedC,
    Random random,
  ) {
    double between(double lo, double hi) =>
        lo + random.nextDouble() * (hi - lo);
    final (lo, hi) = destination.waterTempC;
    final seasonal = hi - lo >= 6;
    final summer = seasonal
        ? ((plannedC - lo) / (hi - lo)).clamp(0.0, 1.0)
        : 0.0;
    final stratified = seasonal && destination.stratifies;
    final (double layer, double depth, double width) = switch ((
      seasonal,
      stratified,
      destination.freshwater,
    )) {
      (true, true, _) => (0.3 + 9 * summer, between(5, 9), 1.5),
      (true, false, _) => (0.5 + 5 * summer, between(10, 20), 3.0),
      (false, _, true) => (0.2, 5.0, 2.0),
      (false, _, false) => (between(0.3, 1.3), between(15, 30), 5.0),
    };
    return WaterColumn(
      surfaceC: stratified ? plannedC + layer : plannedC,
      deepC: stratified ? plannedC : plannedC - layer,
      thermoclineM: depth,
      widthM: width,
    );
  }

  final double surfaceC;
  final double deepC;

  /// The middle of the thermocline, and how gradually it changes.
  final double thermoclineM;
  final double widthM;

  /// How long the sensor takes to follow the water, in seconds.
  static const sensorLagSec = 75.0;

  /// The water temperature at [depth] metres.
  double at(double depth) =>
      deepC + (surfaceC - deepC) / (1 + exp((depth - thermoclineM) / widthM));

  /// What a dive computer logs over [samples]: the water at each depth,
  /// drifting slowly by a tenth or two, followed by a sensor that lags
  /// behind it and reads in steps of 0.1 degrees.
  List<double> trace(List<ShapeSample> samples, Random random) {
    final drift = 0.1 + random.nextDouble() * 0.1;
    final period = 600 + random.nextDouble() * 900;
    final phase = random.nextDouble() * 2 * pi;
    var sensed = at(0);
    var shown = _tenth(sensed);
    var last = samples.isEmpty ? 0 : samples.first.t;
    return [
      for (final s in samples)
        () {
          final water =
              at(s.depth) + drift * sin(2 * pi * s.t / period + phase);
          sensed += (water - sensed) * (1 - exp(-(s.t - last) / sensorLagSec));
          last = s.t;
          // A reading moves on only once the sensor is clearly past the
          // next step, so it never flickers on a step's edge.
          if ((sensed - shown).abs() > 0.06) shown = _tenth(sensed);
          return shown;
        }(),
    ];
  }

  static double _tenth(double v) => (v * 10).roundToDouble() / 10;
}
