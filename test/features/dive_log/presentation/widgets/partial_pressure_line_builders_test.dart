import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/partial_pressure_line_builders.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';

/// A gas switch is a step in every partial-pressure curve. Drawn as a spline
/// the line overshoots each step, dipping below the gas before the switch and
/// spiking past it after (issue #577). The lines are straight between samples.
void main() {
  final profile = [
    for (var t = 0; t <= 300; t += 60)
      DiveProfilePoint(timestamp: t, depth: 21.0),
  ];
  // Back gas, then a switch to a richer gas at t=180.
  const stepCurve = [0.7, 0.7, 0.7, 1.55, 1.55, 1.55];
  const band = MetricBand(top: 0, span: 30);

  List<int> allIndices(List<num> values) => [
    for (var i = 0; i < values.length; i++) i,
  ];
  List<FlSpot> noLeadIn(List<FlSpot> spots, double surfaceY) => spots;
  double surfaceValue(double first) => first;

  final builders = {
    'ppO2': buildPpO2Line,
    'ppN2': buildPpN2Line,
    'ppHe': buildPpHeLine,
  };

  for (final MapEntry(key: name, value: build) in builders.entries) {
    test('$name is drawn straight between samples, so a switch cannot '
        'overshoot', () {
      final line = build(
        band,
        stepCurve,
        2.0,
        profile,
        allIndices,
        noLeadIn,
        surfaceValue,
      );
      expect(line.isCurved, isFalse);
      expect(line.spots, hasLength(stepCurve.length));
    });
  }
}
