import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

const _schedule = DecoSchedule(stops: [], ttsSeconds: 0);

BailoutPoint _worstCase() => const BailoutPoint(
  runtimeSeconds: 600,
  depthMeters: 40,
  ttsSeconds: 300,
  litersRequired: 1000,
  schedule: _schedule,
);

void main() {
  test('worst-case rows become one continuous profile: CCR legs then the OC '
      'ascent, both already absolutely timed', () {
    final bailout = BailoutOutcome(
      points: [_worstCase()],
      worstCase: _worstCase(),
      availableLiters: 1200,
      worstCaseRows: const [
        // The CCR leg down to the worst-case instant.
        PlanScheduleRow(
          kind: PlanScheduleRowKind.descent,
          depthMeters: 40,
          durationSeconds: 600,
          runtimeSeconds: 600,
          gasFO2: 18,
          gasFHe: 45,
          tankId: 'dil',
          gasSwitch: true,
        ),
        // The OC ascent from the worst-case instant, with a stop and a
        // gas switch to a deco tank on the way up.
        PlanScheduleRow(
          kind: PlanScheduleRowKind.ascent,
          depthMeters: 21,
          durationSeconds: 60,
          runtimeSeconds: 660,
          gasFO2: 18,
          gasFHe: 45,
          tankId: 'bailout1',
          gasSwitch: true,
        ),
        PlanScheduleRow(
          kind: PlanScheduleRowKind.stop,
          depthMeters: 21,
          durationSeconds: 120,
          runtimeSeconds: 780,
          gasFO2: 50,
          gasFHe: 0,
          tankId: 'deco',
          gasSwitch: true,
        ),
      ],
      bailoutTanks: const [],
      bailoutTankUsages: const [],
      ceilingTrace: const [(600, 0.0), (660, 6.0), (780, 3.0)],
    );

    final series = buildBailoutCanvasSeries(bailout);

    expect(series.profile.map((p) => (p.timeSeconds, p.depth)), [
      (0.0, 0.0),
      (600.0, 40.0),
      (660.0, 21.0),
      (780.0, 21.0),
    ]);
    expect(series.maxDepth, 40);
    expect(series.maxTimeSeconds, 780);

    // The very first row's gas is the starting gas, not a switch into it.
    expect(series.gasSwitches, hasLength(2));
    expect(series.gasSwitches[0].timeSeconds, 600); // ascent begins
    expect(series.gasSwitches[1].timeSeconds, 660); // stop begins

    expect(series.stopLabels, hasLength(1));
    expect(series.stopLabels.single.timeSeconds, 660);
    expect(series.stopLabels.single.durationSeconds, 120);

    // BailoutOutcome.ceilingTrace maps straight through, not the CCR plan's
    // own ceiling.
    expect(series.ceiling.map((p) => (p.timeSeconds, p.depth)), [
      (600.0, 0.0),
      (660.0, 6.0),
      (780.0, 3.0),
    ]);
  });

  test('an empty row list yields a single surface point', () {
    final bailout = BailoutOutcome(
      points: [_worstCase()],
      worstCase: _worstCase(),
      availableLiters: 1200,
      worstCaseRows: const [],
      bailoutTanks: const [],
      bailoutTankUsages: const [],
      ceilingTrace: const [],
    );

    final series = buildBailoutCanvasSeries(bailout);

    expect(series.profile, [const CanvasPoint(0, 0)]);
    expect(series.maxTimeSeconds, 0);
    expect(series.maxDepth, 0);
  });
}
