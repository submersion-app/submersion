import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';

void main() {
  const late = GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: 1630,
    idealDepth: 21,
    switchTimestamp: 1910,
    switchDepth: 15,
    endTimestamp: 1910,
    delaySeconds: 280,
    depthDelayMeters: 6,
    extraDecoSeconds: 120,
  );

  test('window contains its inclusive span only', () {
    expect(late.contains(1629), isFalse);
    expect(late.contains(1630), isTrue);
    expect(late.contains(1910), isTrue);
    expect(late.contains(1911), isFalse);
    expect(late.isMissed, isFalse);
  });

  test('copyWith replaces only the given fields', () {
    final changed = late.copyWith(extraDecoSeconds: 60);
    expect(changed.extraDecoSeconds, 60);
    expect(changed.copyWith(extraDecoSeconds: 120), late);
  });

  test('efficiency finds the window under a timestamp', () {
    const efficiency = GasSwitchEfficiency(
      evaluated: true,
      windows: [late],
      totalExtraDecoSeconds: 120,
    );
    expect(efficiency.windowAt(1700), late);
    expect(efficiency.windowAt(100), isNull);
    expect(GasSwitchEfficiency.notEvaluated.evaluated, isFalse);
    expect(GasSwitchEfficiency.notEvaluated.windows, isEmpty);
    expect(efficiency.copyWith(evaluated: false).evaluated, isFalse);
  });

  test('at a boundary two windows share, the starting one is current', () {
    final next = late.copyWith(
      fO2: 1.0,
      idealTimestamp: 1910,
      endTimestamp: 2200,
    );
    final efficiency = GasSwitchEfficiency(
      evaluated: true,
      windows: [late, next],
    );
    expect(efficiency.windowAt(1910), next);
    expect(efficiency.windowAt(1909), late);
  });

  test('OptimalOcAscentGas exposes its gases', () {
    const air = AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66);
    const ean50 = AvailableGas(fN2: 0.5, fHe: 0, maxPpO2Mod: 22);
    final plan = OptimalOcAscentGas(gases: [air, ean50], maxPpO2: 1.6);
    expect(plan.gases, [air, ean50]);
  });

  test('withSameConfig copies configuration with fresh tissues', () {
    final engine = BuhlmannAlgorithm(
      gfLow: 0.4,
      gfHigh: 0.8,
      lastStopDepth: 6,
      stopIncrement: 3,
      ascentRate: 10,
      environment: DiveEnvironment.standard,
    )..calculateSegment(depthMeters: 40, durationSeconds: 1200);
    final copy = engine.withSameConfig();
    expect(copy.gfLow, 0.4);
    expect(copy.gfHigh, 0.8);
    expect(copy.lastStopDepth, 6);
    expect(copy.stopIncrement, 3);
    expect(copy.ascentRate, 10);
    expect(copy.environment, engine.environment);
    expect(
      copy.compartments.first.currentPN2,
      BuhlmannAlgorithm().compartments.first.currentPN2,
    );
  });
}
