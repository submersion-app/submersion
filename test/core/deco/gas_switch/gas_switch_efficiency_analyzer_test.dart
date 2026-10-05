import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency_analyzer.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  BuhlmannAlgorithm newEngine() => BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7);
  final air = gasOf(0.21);
  final ean50 = gasOf(0.5);
  final o2 = gasOf(1.0);

  GasSwitchEfficiency? run(
    List<ProfileGasSegment> segments, {
    List<(int, double)> waypoints = standardDecoDive,
    List<AvailableGas>? gases,
  }) {
    final profile = sampleProfile(waypoints);
    final available = gases ?? [air, ean50, o2];
    final plan = OptimalOcAscentGas(gases: available, maxPpO2: 1.6);
    final statuses = newEngine().processProfileWithGasSegments(
      depths: profile.depths,
      timestamps: profile.timestamps,
      gasSegments: segments,
      ascentGasPlan: plan,
    );
    return GasSwitchEfficiencyAnalyzer(
      newEngine: newEngine,
      gases: available,
      maxPpO2: 1.6,
    ).analyze(
      depths: profile.depths,
      timestamps: profile.timestamps,
      gasSegments: segments,
      ceilingCurve: [for (final s in statuses) s.ceilingMeters],
      ttsCurve: [for (final s in statuses) s.ttsSeconds],
    );
  }

  test('fewer than two gases is not applicable', () {
    expect(run([seg(0, 0.21)], gases: [air]), isNull);
  });

  test('on-time switches are evaluated with nothing flagged', () {
    final result = run([seg(0, 0.21), seg(1690, 0.5), seg(2540, 1.0)])!;
    expect(result.evaluated, isTrue);
    expect(result.windows, isEmpty);
    expect(result.totalExtraDecoSeconds, 0);
  });

  test('a switch 6 m shallower than ideal is late by depth', () {
    final result = run([seg(0, 0.21), seg(1910, 0.5), seg(2540, 1.0)])!;
    final window = result.windows.single;
    expect(window.kind, GasSwitchWindowKind.late);
    expect(window.fO2, closeTo(0.5, 1e-9));
    expect(window.idealTimestamp, 1630);
    expect(window.idealDepth, closeTo(21, 1e-9));
    expect(window.switchTimestamp, 1910);
    expect(window.switchDepth, closeTo(15, 1e-9));
    expect(window.depthDelayMeters, closeTo(6, 1e-9));
    expect(window.delaySeconds, 280);
    expect(window.extraDecoSeconds, greaterThan(0));
    expect(result.totalExtraDecoSeconds, window.extraDecoSeconds);
  });

  test('a switch 130 s after the ideal time is late by time', () {
    final result = run([seg(0, 0.21), seg(1760, 0.5), seg(2540, 1.0)])!;
    final window = result.windows.single;
    expect(window.kind, GasSwitchWindowKind.late);
    expect(window.delaySeconds, 130);
    expect(window.depthDelayMeters, lessThanOrEqualTo(3));
  });

  test('120 s at the stop is inside the tolerance', () {
    final result = run([seg(0, 0.21), seg(1750, 0.5), seg(2540, 1.0)])!;
    expect(result.windows, isEmpty);
  });

  test('a never-breathed gas is missed', () {
    final result = run([seg(0, 0.21), seg(2540, 1.0)])!;
    final window = result.windows.single;
    expect(window.kind, GasSwitchWindowKind.missed);
    expect(window.switchTimestamp, isNull);
    expect(window.switchDepth, isNull);
    expect(window.depthDelayMeters, isNull);
    expect(window.endTimestamp, 2510);
    expect(window.delaySeconds, 2510 - 1630);
    expect(window.extraDecoSeconds, greaterThan(0));
  });

  test('two flagged windows: total is positive and at most the sum', () {
    final result = run([seg(0, 0.21), seg(1910, 0.5), seg(2700, 1.0)])!;
    expect(result.windows, hasLength(2));
    final sum = result.windows.fold<int>(0, (s, w) => s + w.extraDecoSeconds);
    expect(result.totalExtraDecoSeconds, greaterThan(0));
    expect(result.totalExtraDecoSeconds, lessThanOrEqualTo(sum));
  });

  test('a no-deco dive is not evaluated', () {
    final result = run(
      [seg(0, 0.21)],
      waypoints: [(0, 0), (60, 26), (540, 26), (720, 5), (900, 5), (930, 0)],
      gases: [air, ean50],
    )!;
    expect(result.evaluated, isFalse);
    expect(result.windows, isEmpty);
  });

  test('a deco dive that never went below any MOD is not evaluated', () {
    final result = run(
      [seg(0, 0.21)],
      waypoints: [
        (0, 0),
        (60, 20),
        (5400, 20),
        (5460, 9),
        (5700, 9),
        (5720, 6),
        (6320, 6),
        (6340, 3),
        (6940, 3),
        (6960, 0),
      ],
      gases: [air, ean50],
    )!;
    expect(result.evaluated, isFalse);
  });

  test('air breaks on O2 are not flagged', () {
    final result = run([
      seg(0, 0.21),
      seg(1690, 0.5),
      seg(2540, 1.0),
      seg(2780, 0.21),
      seg(3080, 1.0),
    ])!;
    expect(result.windows, isEmpty);
  });
}
