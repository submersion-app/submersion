import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

import '../../../../core/deco/gas_switch/gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final gases = [gasOf(0.21), gasOf(0.5), gasOf(1.0)];
  final lateSegments = [seg(0, 0.21), seg(1910, 0.5), seg(2540, 1.0)];

  ProfileAnalysis analyze({AscentGasPlan? plan, DiveMode mode = DiveMode.oc}) =>
      ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7).analyze(
        diveId: 'd1',
        depths: dive.depths,
        timestamps: dive.timestamps,
        gasSegments: lateSegments,
        ascentGasPlan: plan,
        diveMode: mode,
      );

  test('an OC multi-gas dive carries its gas-switch efficiency', () {
    final analysis = analyze(
      plan: OptimalOcAscentGas(gases: gases, maxPpO2: 1.6),
    );
    final efficiency = analysis.gasSwitchEfficiency!;
    expect(efficiency.evaluated, isTrue);
    expect(efficiency.windows.single.kind, GasSwitchWindowKind.late);
  });

  test('no optimal plan means no efficiency', () {
    expect(analyze().gasSwitchEfficiency, isNull);
  });

  test('every deco value matches the engine run alone', () {
    final plan = OptimalOcAscentGas(gases: gases, maxPpO2: 1.6);
    final analysis = analyze(plan: plan);
    final statuses = BuhlmannAlgorithm(gfLow: 0.3, gfHigh: 0.7)
        .processProfileWithGasSegments(
          depths: dive.depths,
          timestamps: dive.timestamps,
          gasSegments: lateSegments,
          ascentGasPlan: plan,
        );
    expect(analysis.ttsCurve, statuses.map((s) => s.ttsSeconds).toList());
    expect(
      analysis.ceilingCurve,
      statuses.map((s) => s.ceilingMeters).toList(),
    );
    expect(analysis.ndlCurve, statuses.map((s) => s.ndlSeconds).toList());
  });

  test('copyWith carries the field', () {
    const efficiency = GasSwitchEfficiency(evaluated: true);
    final copy = ProfileAnalysis.empty().copyWith(
      gasSwitchEfficiency: efficiency,
    );
    expect(copy.gasSwitchEfficiency, efficiency);
    expect(copy.copyWith().gasSwitchEfficiency, efficiency);
    expect(ProfileAnalysis.empty().gasSwitchEfficiency, isNull);
  });
}
