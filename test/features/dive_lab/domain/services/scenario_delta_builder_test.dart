import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_delta_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

import '../support/synthetic_dives.dart';

ProfileAnalysis _analyze(SyntheticDive d, {double gfHigh = 0.70}) =>
    ProfileAnalysisService(gfLow: 0.30, gfHigh: gfHigh).analyze(
      diveId: 'd',
      depths: d.depths,
      timestamps: d.timestamps,
      gasSegments: TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      ).toGasSegments(),
    );

const _tank = TankConsumption(
  tankId: 'back',
  startPressureBar: 200,
  endPressureBar: 80,
  litersUsed: 2000,
  source: PressureSource.measured,
);

void main() {
  test('identical timelines produce all-zero deltas and an empty verdict', () {
    final d = squareDive();
    final a = _analyze(d);
    final deltas = buildDeltas(
      actual: a,
      counterfactual: a,
      actualDepths: d.depths,
      counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps,
      counterfactualTimestamps: d.timestamps,
      branchIndex: d.indexAt(900),
      consumption: const ScenarioConsumption(
        actual: [_tank],
        counterfactual: [_tank],
        reservePressureBar: 50,
      ),
    );
    expect(
      deltas.where((x) => x.delta != null).every((x) => x.delta!.abs() < 1e-9),
      isTrue,
    );
    expect(selectVerdictDeltas(deltas), isEmpty);
    expect(deltas.map((x) => x.metric), contains(DeltaMetric.runtime));
    expect(deltas.map((x) => x.metric), contains(DeltaMetric.surfaceGf));
    expect(
      deltas.firstWhere((x) => x.metric == DeltaMetric.tankEndPressure).tankId,
      'back',
    );
  });

  test('a longer dive at a higher GF shows the expected signs', () {
    final d = squareDive(bottomMinutes: 25);
    final longer = squareDive(bottomMinutes: 35);
    final a = _analyze(d);
    final c = _analyze(longer, gfHigh: 0.90);
    final deltas = buildDeltas(
      actual: a,
      counterfactual: c,
      actualDepths: d.depths,
      counterfactualDepths: longer.depths,
      actualTimestamps: d.timestamps,
      counterfactualTimestamps: longer.timestamps,
      branchIndex: d.indexAt(900),
      consumption: const ScenarioConsumption(
        actual: [_tank],
        counterfactual: [
          TankConsumption(
            tankId: 'back',
            startPressureBar: 200,
            endPressureBar: 40,
            litersUsed: 3000,
            source: PressureSource.estimated,
          ),
        ],
        reservePressureBar: 50,
      ),
    );
    double delta(DeltaMetric m) =>
        deltas.firstWhere((x) => x.metric == m).delta!;
    expect(delta(DeltaMetric.runtime), 600);
    expect(delta(DeltaMetric.surfaceGf), greaterThan(0));
    expect(delta(DeltaMetric.cnsEnd), greaterThan(0));
    expect(delta(DeltaMetric.tankEndPressure), -40);
    final verdict = selectVerdictDeltas(deltas);
    expect(verdict, hasLength(3));
    expect(
      verdict.first.significance,
      greaterThanOrEqualTo(verdict.last.significance),
    );
  });

  test('gas-out and min-gas rows appear only when they exist', () {
    final d = squareDive();
    final a = _analyze(d);
    final none = buildDeltas(
      actual: a,
      counterfactual: a,
      actualDepths: d.depths,
      counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps,
      counterfactualTimestamps: d.timestamps,
      branchIndex: 10,
      consumption: const ScenarioConsumption(
        actual: [_tank],
        counterfactual: [_tank],
        reservePressureBar: 50,
      ),
    );
    expect(none.any((x) => x.metric == DeltaMetric.gasOutTime), isFalse);
    expect(
      none.any((x) => x.metric == DeltaMetric.minGasMarginAtBranch),
      isFalse,
    );
    final out = buildDeltas(
      actual: a,
      counterfactual: a,
      actualDepths: d.depths,
      counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps,
      counterfactualTimestamps: d.timestamps,
      branchIndex: 10,
      consumption: const ScenarioConsumption(
        actual: [_tank],
        counterfactual: [
          TankConsumption(
            tankId: 'back',
            startPressureBar: 200,
            endPressureBar: 0,
            litersUsed: 9000,
            emptyAtSeconds: 2400,
            source: PressureSource.estimated,
          ),
        ],
        reservePressureBar: 50,
      ),
    );
    final go = out.firstWhere((x) => x.metric == DeltaMetric.gasOutTime);
    expect(go.counterfactual, 2400);
    expect(go.actual, isNull);
    expect(go.tankId, 'back');
  });

  test('ceiling violations count samples below the ceiling after branch', () {
    final d = squareDive();
    final a = _analyze(d);
    final ceilings = List<double>.from(a.ceilingCurve);
    final i0 = d.indexAt(900);
    for (var k = 1; k <= 4; k++) {
      ceilings[i0 + k] = d.depths[i0 + k] + 5;
    }
    final c = a.copyWith(ceilingCurve: ceilings);
    final deltas = buildDeltas(
      actual: a,
      counterfactual: c,
      actualDepths: d.depths,
      counterfactualDepths: d.depths,
      actualTimestamps: d.timestamps,
      counterfactualTimestamps: d.timestamps,
      branchIndex: i0,
      consumption: const ScenarioConsumption(
        actual: [],
        counterfactual: [],
        reservePressureBar: 50,
      ),
    );
    // The synthetic ascent already breaches the calculated ceiling on its
    // own, so assert the forced excess on top of it.
    expect(
      deltas.firstWhere((x) => x.metric == DeltaMetric.ceilingViolations).delta,
      4,
    );
    expect(
      deltas
          .firstWhere((x) => x.metric == DeltaMetric.worstCeilingViolation)
          .counterfactual,
      greaterThanOrEqualTo(5 - 1e-9),
    );
  });
}
