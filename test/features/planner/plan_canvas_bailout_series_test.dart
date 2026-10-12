import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

BailoutPoint _worstCase({int ttsSeconds = 0}) => BailoutPoint(
  runtimeSeconds: 600,
  depthMeters: 40,
  ttsSeconds: ttsSeconds,
  litersRequired: 1000,
  // schedule.ttsSeconds must match the point's own ttsSeconds: that is
  // where BailoutSolver actually derives it from (`ttsSeconds:
  // schedule.ttsSeconds`), and buildBailoutCanvasSeries reads it off the
  // schedule, not off the point.
  schedule: DecoSchedule(stops: const [], ttsSeconds: ttsSeconds),
);

void main() {
  test('ccrRows then ocStops become one continuous, stepped profile: a flat '
      'hold at each stop, not a smooth diagonal between them', () {
    final bailout = BailoutOutcome(
      points: [_worstCase(ttsSeconds: 420)],
      worstCase: _worstCase(ttsSeconds: 420),
      availableLiters: 1200,
      // The CCR leg down to the worst-case instant.
      ccrRows: const [
        PlanScheduleRow(
          kind: PlanScheduleRowKind.descent,
          depthMeters: 40,
          durationSeconds: 600,
          runtimeSeconds: 600,
          gasFO2: 0.18,
          gasFHe: 0.45,
          tankId: 'dil',
          gasSwitch: true,
        ),
      ],
      worstCaseRows: const [],
      // The OC ascent from the worst-case instant: a stop at 21 m on a
      // deco gas, arriving 60 s after leaving 40 m and holding 120 s.
      ocStops: const [
        PlanStop(
          depthMeters: 21,
          durationSeconds: 120,
          gasFO2: 0.50,
          gasFHe: 0.0,
          tankId: 'deco',
          arrivalRuntimeSeconds: 660,
        ),
      ],
      bailoutTanks: const [],
      bailoutTankUsages: const [],
      ceilingTrace: const [(600, 0.0), (660, 6.0), (780, 3.0)],
    );

    final series = buildBailoutCanvasSeries(bailout);

    expect(series.profile.map((p) => (p.timeSeconds, p.depth)), [
      (0.0, 0.0),
      (600.0, 40.0), // CCR leg ends at the worst-case instant
      (660.0, 21.0), // travel up to the stop
      (780.0, 21.0), // flat hold for the stop's own duration
      (1020.0, 0.0), // worst.runtimeSeconds + worst.ttsSeconds (600+420)
    ]);
    expect(series.maxDepth, 40);
    expect(series.maxTimeSeconds, 1020);

    // The CCR leg's own gas is the starting gas, not a switch into it;
    // the stop's gas differs from the CCR leg's, so that is one.
    expect(series.gasSwitches, hasLength(1));
    expect(series.gasSwitches.single.timeSeconds, 660);

    expect(series.stopLabels, hasLength(1));
    expect(series.stopLabels.single.timeSeconds, 660);
    expect(series.stopLabels.single.durationSeconds, 120);

    // BailoutOutcome.ceilingTrace maps straight through, not the CCR
    // plan's own ceiling.
    expect(series.ceiling.map((p) => (p.timeSeconds, p.depth)), [
      (600.0, 0.0),
      (660.0, 6.0),
      (780.0, 3.0),
    ]);
  });

  test('a gas switch on a depth-changing CCR leg marks the leg\'s own start, '
      'not its end depth, so the marker lands on the drawn line', () {
    final bailout = BailoutOutcome(
      points: [_worstCase()],
      worstCase: _worstCase(),
      availableLiters: 1200,
      // The inserted gas-switch stop (#3263) can keep the OLD diluent
      // (whichever is more conservative), so the switch is flagged on
      // the NEXT leg instead -- here a 40 m -> 60 m descent, not a flat
      // leg, so its end depth (60 m) differs from where it starts (40
      // m, where the switch and the leg both actually begin).
      ccrRows: const [
        PlanScheduleRow(
          kind: PlanScheduleRowKind.descent,
          depthMeters: 40,
          durationSeconds: 600,
          runtimeSeconds: 600,
          gasFO2: 0.18,
          gasFHe: 0.45,
          tankId: 'dilA',
          gasSwitch: true,
        ),
        PlanScheduleRow(
          kind: PlanScheduleRowKind.descent,
          depthMeters: 60,
          durationSeconds: 120,
          runtimeSeconds: 720,
          gasFO2: 0.10,
          gasFHe: 0.70,
          tankId: 'dilB',
          gasSwitch: true,
        ),
      ],
      worstCaseRows: const [],
      ocStops: const [],
      bailoutTanks: const [],
      bailoutTankUsages: const [],
      ceilingTrace: const [],
    );

    final series = buildBailoutCanvasSeries(bailout);

    expect(series.gasSwitches, hasLength(1));
    final marker = series.gasSwitches.single;
    expect(marker.timeSeconds, 600, reason: 'the second leg\'s own start');
    expect(
      marker.depth,
      40,
      reason: 'the depth the second leg starts from, not its end depth (60)',
    );
    // The marker's own point must actually sit on the drawn profile line.
    expect(
      series.profile.map((p) => (p.timeSeconds, p.depth)),
      contains((600.0, 40.0)),
    );
  });

  test('no CCR rows and no stops yields a single surface point', () {
    final bailout = BailoutOutcome(
      points: [_worstCase()],
      worstCase: _worstCase(),
      availableLiters: 1200,
      ccrRows: const [],
      worstCaseRows: const [],
      ocStops: const [],
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
