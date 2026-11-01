import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/compare_columns.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

import '../support/synthetic_dives.dart';

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 24,
  startPressure: 220,
  gasMix: _air,
);

domain.DivePlan _plan({double depth = 40, int minutes = 25}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Wreck',
  gfLow: 30,
  gfHigh: 70,
  tanks: const [_airTank],
  segments: [
    PlanSegment.travel(
      id: 'seg-1',
      fromDepth: 0,
      targetDepth: depth,
      tankId: 'tank-1',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'seg-2',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'tank-1',
      gasMix: _air,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

PlanOutcome _outcome(domain.DivePlan plan) =>
    const PlanEngine(config: PlanEngineConfig()).compute(plan);

List<({int timestamp, double depth})> _planSamples(PlanOutcome outcome) => [
  (timestamp: 0, depth: 0.0),
  for (final row in outcome.schedule)
    (timestamp: row.runtimeSeconds, depth: row.depthMeters),
];

ProfileAnalysis _analyze(SyntheticDive d) =>
    ProfileAnalysisService(gfLow: 0.30, gfHigh: 0.70).analyze(
      diveId: 'd',
      depths: d.depths,
      timestamps: d.timestamps,
      gasSegments: TankSchedule.fromDive(
        tanks: d.tanks,
        switches: d.switches,
      ).toGasSegments(),
    );

List<DiveProfilePoint> _profile(SyntheticDive d) => [
  for (var i = 0; i < d.depths.length; i++)
    DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
];

Dive _dive({
  double? maxDepth,
  Duration? runtime,
  Duration? bottomTime,
  List<DiveProfilePoint> profile = const [],
}) => Dive(
  id: 'd',
  dateTime: DateTime.utc(2026),
  maxDepth: maxDepth,
  runtime: runtime,
  bottomTime: bottomTime,
  profile: profile,
);

void main() {
  group('plannedColumn', () {
    test('a no-deco plan shows the minutes left on the bottom leg', () {
      final outcome = _outcome(_plan(depth: 18, minutes: 20));
      final column = plannedColumn(outcome: outcome, surfacePressureBar: 1.0)!;

      expect(outcome.ndlAtBottom, greaterThan(0));
      expect(column.ndl, CompareNdlLeft(outcome.ndlAtBottom));
      expect(column.decoStartSeconds, isNull);
      expect(column.decoRequiredSeconds, 0);
      expect(column.kind, CompareLineKind.planned);
      expect(column.id, 'planned');
    });

    test('a deco plan shows Deco at the first ceiling sample', () {
      final outcome = _outcome(_plan());
      final column = plannedColumn(outcome: outcome, surfacePressureBar: 1.0)!;

      final first = outcome.ceilingTrace.firstWhere((s) => s.$2 > 0.05);
      expect(outcome.ndlAtBottom, -1);
      expect(column.ndl, CompareDecoAt(first.$1));
      expect(column.decoStartSeconds, first.$1);
    });

    test('reads depth, runtime and stops from the outcome', () {
      final outcome = _outcome(_plan());
      final column = plannedColumn(outcome: outcome, surfacePressureBar: 1.0)!;

      expect(column.maxDepthMeters, outcome.maxDepth);
      expect(column.runtimeSeconds, outcome.runtimeSeconds);
      expect(column.decoRequiredSeconds, outcome.totalDecoSeconds);
      expect(column.decoRequiredSeconds, greaterThan(0));
      expect(
        column.bottomTimeSeconds,
        BottomTimeCalculator.secondsFromSamples(_planSamples(outcome)),
      );
    });

    test('a plan has no deco done', () {
      final outcome = _outcome(_plan());
      final column = plannedColumn(outcome: outcome, surfacePressureBar: 1.0)!;

      expect(column.decoDoneSeconds, isNull);
    });

    test('a plan with no schedule has no column', () {
      final empty = _plan().copyWith(segments: const []);
      final outcome = _outcome(empty);

      expect(plannedColumn(outcome: outcome, surfacePressureBar: 1.0), isNull);
    });

    test('surface GF reads the surfaced tissues at the surface pressure', () {
      final outcome = _outcome(_plan());
      double gfAt(double bar) =>
          plannedColumn(outcome: outcome, surfacePressureBar: bar)!.surfaceGf!;

      final comps = outcome.surfacedTissue.compartments;
      final expected =
          comps
              .map((c) => c.gradientFactor(1.0))
              .reduce((a, b) => a > b ? a : b) *
          100;
      expect(gfAt(1.0), closeTo(expected, 1e-9));
      // Thinner air at altitude leaves less margin for the same tissues.
      expect(gfAt(0.8), greaterThan(gfAt(1.0)));
    });
  });

  group('divedColumn', () {
    test('a dive that hit deco reads Deco at its first negative NDL', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final analysis = _analyze(d);
      final column = divedColumn(
        dive: _dive(maxDepth: 40),
        profile: _profile(d),
        analysis: analysis,
      );

      final first = analysis.ndlCurve.indexWhere((n) => n < 0);
      expect(first, greaterThan(0));
      expect(column.ndl, CompareDecoAt(d.timestamps[first]));
      expect(column.decoStartSeconds, d.timestamps[first]);
    });

    test('the deep phase ends at the last sample at 85 percent of max', () {
      // 5 minutes at 30 m, then a long 12 m tail. Bottom time's threshold is
      // 10 m, so its end sits on the tail; NDL has to come from the end of 30 m.
      const step = 10;
      final depths = <double>[
        for (var i = 0; i <= 9; i++) 30.0 * i / 9,
        for (var i = 0; i < 30; i++) 30.0,
        for (var i = 0; i < 12; i++) 30.0 - 1.5 * i,
        for (var i = 0; i < 180; i++) 12.0,
        for (var i = 1; i <= 8; i++) 12.0 - 1.5 * i,
      ];
      final timestamps = [for (var i = 0; i < depths.length; i++) i * step];
      final analysis = ProfileAnalysisService(
        gfLow: 0.30,
        gfHigh: 0.70,
      ).analyze(diveId: 'd', depths: depths, timestamps: timestamps);
      final profile = [
        for (var i = 0; i < depths.length; i++)
          DiveProfilePoint(timestamp: timestamps[i], depth: depths[i]),
      ];
      final column = divedColumn(
        dive: _dive(maxDepth: 30),
        profile: profile,
        analysis: analysis,
      );

      final deepEnd = depths.lastIndexWhere((d) => d >= 30 * 0.85);
      final tail = depths.lastIndexWhere((d) => d >= 10);
      expect(analysis.ndlCurve[deepEnd], greaterThan(0));
      expect(analysis.ndlCurve[tail], isNot(analysis.ndlCurve[deepEnd]));
      expect(column.ndl, CompareNdlLeft(analysis.ndlCurve[deepEnd]));
    });

    test('deco required sums the stops at the deep phase end', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final analysis = _analyze(d);
      final column = divedColumn(
        dive: _dive(maxDepth: 40),
        profile: _profile(d),
        analysis: analysis,
      );

      final deepEnd = d.depths.lastIndexWhere((depth) => depth >= 40 * 0.85);
      final stops = analysis.decoStatuses[deepEnd].decoStops;
      expect(stops, isNotEmpty);
      expect(
        column.decoRequiredSeconds,
        stops.fold<int>(0, (sum, s) => sum + s.durationSeconds),
      );
    });

    test('deco done counts obligation time after the deep phase end', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final analysis = _analyze(d);
      final column = divedColumn(
        dive: _dive(maxDepth: 40),
        profile: _profile(d),
        analysis: analysis,
      );

      final deepEnd = d.depths.lastIndexWhere((depth) => depth >= 40 * 0.85);
      var expected = 0;
      for (var i = deepEnd + 1; i < d.timestamps.length; i++) {
        if (analysis.ndlCurve[i] < 0) {
          expected += d.timestamps[i] - d.timestamps[i - 1];
        }
      }
      expect(expected, greaterThan(0));
      expect(column.decoDoneSeconds, expected);
    });

    test('runtime and surface GF come from the dive and its analysis', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final analysis = _analyze(d);
      final column = divedColumn(
        dive: _dive(maxDepth: 40, runtime: const Duration(minutes: 41)),
        profile: _profile(d),
        analysis: analysis,
      );

      expect(column.runtimeSeconds, 41 * 60);
      expect(column.surfaceGf, analysis.surfaceGfCurve!.last);
      expect(column.kind, CompareLineKind.asDived);
      expect(column.id, 'dived');
    });

    test('a dive with no profile keeps its facts and blanks the rest', () {
      final column = divedColumn(
        dive: _dive(
          maxDepth: 30,
          runtime: const Duration(minutes: 40),
          bottomTime: const Duration(minutes: 28),
        ),
        profile: const [],
        analysis: null,
      );

      expect(column.maxDepthMeters, 30);
      expect(column.bottomTimeSeconds, 28 * 60);
      expect(column.runtimeSeconds, 40 * 60);
      expect(column.ndl, isNull);
      expect(column.decoRequiredSeconds, isNull);
      expect(column.decoDoneSeconds, isNull);
      expect(column.surfaceGf, isNull);
    });

    test('withheld tissue loading blanks NDL, deco and surface GF', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final withheld = _analyze(d).copyWith(
        ndlCurve: const [],
        decoStatuses: const [],
        surfaceGfCurve: const [],
        tissueLoadingWithheld: true,
      );

      final column = divedColumn(
        dive: _dive(maxDepth: 40),
        profile: _profile(d),
        analysis: withheld,
      );

      expect(column.maxDepthMeters, 40);
      expect(column.ndl, isNull);
      expect(column.decoRequiredSeconds, isNull);
      expect(column.decoDoneSeconds, isNull);
      expect(column.surfaceGf, isNull);
      expect(column.bottomTimeSeconds, isNotNull);
    });
  });

  group('whatIfColumn', () {
    ScenarioOutcome run(SyntheticDive d, int branch, DiveScenario scenario) =>
        const ScenarioEngine().run(
          ScenarioRequest(
            diveId: 'd',
            depths: d.depths,
            timestamps: d.timestamps,
            diveMode: DiveMode.oc,
            tanks: d.tanks,
            gasSwitches: d.switches,
            tankPressures: d.tankPressures,
            startCns: 0,
            startOtu: 0,
            settings: const ScenarioSettings(),
            scenario: scenario,
          ),
        );

    DiveScenario scenario(int branch) => DiveScenario(
      id: 'sc-1',
      diveId: 'd',
      name: 'Slower ascent',
      branchSeconds: branch,
      mode: ScenarioMode.replay,
      interventions: const [ChangeGfIntervention(gfLow: 40, gfHigh: 85)],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('carries the scenario id and name', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final s = scenario(d.timestamps[d.bottomEndIndex + 3]);
      final column = whatIfColumn(scenario: s, outcome: run(d, 0, s));

      expect(column.id, 'sc-1');
      expect(column.title, 'Slower ascent');
      expect(column.kind, CompareLineKind.whatIf);
    });

    test('a branch after the bottom repeats the dive\'s bottom time', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final s = scenario(d.timestamps[d.bottomEndIndex + 3]);
      final outcome = run(d, 0, s);
      final what = whatIfColumn(scenario: s, outcome: outcome);
      final dived = divedColumn(
        dive: _dive(maxDepth: 40),
        profile: _profile(d),
        analysis: outcome.actual,
      );

      expect(what.bottomTimeSeconds, dived.bottomTimeSeconds);
      expect(what.maxDepthMeters, dived.maxDepthMeters);
    });

    test('runtime spans the counterfactual samples', () {
      final d = squareDive(depth: 40, bottomMinutes: 25);
      final s = scenario(d.timestamps[d.bottomEndIndex + 3]);
      final outcome = run(d, 0, s);
      final column = whatIfColumn(scenario: s, outcome: outcome);

      expect(
        column.runtimeSeconds,
        outcome.counterfactualTimestamps.last -
            outcome.counterfactualTimestamps.first,
      );
    });
  });

  group('overshootsPlan', () {
    const planned = CompareColumn(
      id: 'planned',
      kind: CompareLineKind.planned,
      maxDepthMeters: 40,
      bottomTimeSeconds: 1500,
      ndl: CompareNdlLeft(600),
      decoRequiredSeconds: 300,
      runtimeSeconds: 2400,
      surfaceGf: 70,
    );
    CompareColumn dived({
      double? depth,
      int? bottom,
      CompareNdl? ndl,
      int? deco,
      int? runtime,
      double? gf,
    }) => CompareColumn(
      id: 'dived',
      kind: CompareLineKind.asDived,
      maxDepthMeters: depth,
      bottomTimeSeconds: bottom,
      ndl: ndl,
      decoRequiredSeconds: deco,
      runtimeSeconds: runtime,
      surfaceGf: gf,
    );

    test('max depth tolerates half a metre', () {
      expect(
        overshootsPlan(CompareRow.maxDepth, planned, dived(depth: 40.4)),
        isFalse,
      );
      expect(
        overshootsPlan(CompareRow.maxDepth, planned, dived(depth: 40.6)),
        isTrue,
      );
    });

    test('times tolerate 30 seconds', () {
      expect(
        overshootsPlan(CompareRow.bottomTime, planned, dived(bottom: 1529)),
        isFalse,
      );
      expect(
        overshootsPlan(CompareRow.bottomTime, planned, dived(bottom: 1531)),
        isTrue,
      );
      expect(
        overshootsPlan(CompareRow.runtime, planned, dived(runtime: 2431)),
        isTrue,
      );
      expect(
        overshootsPlan(CompareRow.deco, planned, dived(deco: 331)),
        isTrue,
      );
    });

    test('surface GF tolerates one point', () {
      expect(
        overshootsPlan(CompareRow.surfaceGf, planned, dived(gf: 70.9)),
        isFalse,
      );
      expect(
        overshootsPlan(CompareRow.surfaceGf, planned, dived(gf: 71.1)),
        isTrue,
      );
    });

    test('going into deco on a no-deco plan overshoots NDL', () {
      expect(
        overshootsPlan(
          CompareRow.ndl,
          planned,
          dived(ndl: const CompareDecoAt(900)),
        ),
        isTrue,
      );
    });

    test('less time left than planned overshoots NDL', () {
      expect(
        overshootsPlan(
          CompareRow.ndl,
          planned,
          dived(ndl: const CompareNdlLeft(500)),
        ),
        isTrue,
      );
      expect(
        overshootsPlan(
          CompareRow.ndl,
          planned,
          dived(ndl: const CompareNdlLeft(590)),
        ),
        isFalse,
      );
    });

    test('a blank on either side never overshoots', () {
      for (final row in CompareRow.values) {
        expect(overshootsPlan(row, planned, dived()), isFalse);
      }
    });
  });
}
