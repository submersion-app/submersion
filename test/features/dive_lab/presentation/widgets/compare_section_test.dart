import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/compare_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_section.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_table.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../domain/support/synthetic_dives.dart';

const _diveId = 'd';
const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Wreck',
  gfLow: 30,
  gfHigh: 70,
  tanks: const [
    DiveTank(id: 'tank-1', volume: 24, startPressure: 220, gasMix: _air),
  ],
  segments: [
    PlanSegment.travel(
      id: 'seg-1',
      fromDepth: 0,
      targetDepth: 40,
      tankId: 'tank-1',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'seg-2',
      depth: 40,
      durationMinutes: 25,
      tankId: 'tank-1',
      gasMix: _air,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

LinkedPlanComparison _comparison() {
  final plan = _plan();
  const config = PlanEngineConfig();
  final outcome = const PlanEngine(config: config).compute(plan);
  return LinkedPlanComparison(
    plan: plan,
    outcome: outcome,
    overlay: buildPlannedOverlay(plan, config: config, outcome: outcome),
  );
}

DiveScenario _scenario(String id, String name, DateTime when) => DiveScenario(
  id: id,
  diveId: _diveId,
  name: name,
  branchSeconds: 1800,
  mode: ScenarioMode.replay,
  interventions: const [ChangeGfIntervention(gfLow: 40, gfHigh: 85)],
  createdAt: when,
  updatedAt: when,
);

ScenarioOutcome _outcome(DiveScenario scenario) {
  final d = squareDive(depth: 40, bottomMinutes: 25);
  return const ScenarioEngine().run(
    ScenarioRequest(
      diveId: _diveId,
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
}

List<DiveProfilePoint> _profile() {
  final d = squareDive(depth: 40, bottomMinutes: 25);
  return [
    for (var i = 0; i < d.depths.length; i++)
      DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
  ];
}

const _dived = CompareColumn(
  id: 'dived',
  kind: CompareLineKind.asDived,
  maxDepthMeters: 40,
  runtimeSeconds: 2400,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Dive? dive,
    LinkedPlanComparison? comparison,
    List<DiveScenario> scenarios = const [],
    double width = 420,
    CompareColumn dived = _dived,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final shown =
        dive ??
        Dive(
          id: _diveId,
          diveNumber: 1,
          dateTime: DateTime.utc(2026),
          profile: _profile(),
        );
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveProvider.overrideWith((ref, id) async => shown),
          diveProfileProvider.overrideWith((ref, id) async => shown.profile),
          divedColumnProvider.overrideWith((ref, id) async => dived),
          linkedPlanComparisonProvider.overrideWith(
            (ref, id) async => comparison,
          ),
          diveScenariosForDiveProvider.overrideWith(
            (ref, id) async => scenarios,
          ),
          whatIfLineProvider.overrideWith((ref, key) async {
            final scenario = scenarios.firstWhere(
              (s) => s.id == key.scenarioId,
            );
            return (
              outcome: _outcome(scenario),
              column: CompareColumn(
                id: scenario.id,
                kind: CompareLineKind.whatIf,
                title: scenario.name,
                maxDepthMeters: 40,
              ),
            );
          }),
          labRequestInputsProvider.overrideWith((ref, id) async => null),
          labDefaultBranchProvider.overrideWith((ref, id) async => 0),
        ],
        locale: const Locale('en'),
        child: const SingleChildScrollView(
          child: CompareSection(diveId: _diveId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder chip(String label) => find.widgetWithText(FilterChip, label);

  List<String> columnIds(WidgetTester tester) => [
    for (final column
        in tester.widget<CompareTable>(find.byType(CompareTable)).columns)
      column.id,
  ];

  testWidgets('a linked dive has a Planned chip and column', (tester) async {
    await pump(tester, comparison: _comparison());

    expect(chip('Planned'), findsOneWidget);
    expect(columnIds(tester), ['planned', 'dived']);
  });

  testWidgets('a dive with no link has no Planned chip', (tester) async {
    await pump(tester, scenarios: [_scenario('s1', 'Slower', DateTime(2026))]);

    expect(chip('Planned'), findsNothing);
    expect(columnIds(tester), ['dived', 's1']);
  });

  testWidgets('opens with Planned, As dived and the newest what-if', (
    tester,
  ) async {
    await pump(
      tester,
      comparison: _comparison(),
      scenarios: [
        _scenario('new', 'Newest', DateTime(2026, 2)),
        _scenario('old', 'Oldest', DateTime(2026, 1)),
      ],
    );

    expect(columnIds(tester), ['planned', 'dived', 'new']);
  });

  testWidgets('a chip toggles its column and its line', (tester) async {
    await pump(
      tester,
      comparison: _comparison(),
      scenarios: [
        _scenario('new', 'Newest', DateTime(2026, 2)),
        _scenario('old', 'Oldest', DateTime(2026, 1)),
      ],
    );
    int overlays() =>
        tester
            .widget<DiveProfileChart>(find.byType(DiveProfileChart))
            .overlays
            ?.length ??
        0;
    expect(overlays(), 2);

    await tester.tap(chip('Oldest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(columnIds(tester), ['planned', 'dived', 'new', 'old']);
    expect(overlays(), 3);

    await tester.tap(chip('Planned'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(columnIds(tester), ['dived', 'new', 'old']);
    expect(overlays(), 2);
  });

  testWidgets('As dived cannot be turned off and does not look disabled', (
    tester,
  ) async {
    await pump(tester, comparison: _comparison());

    await tester.tap(chip('As dived'), warnIfMissed: false);
    await tester.pump();

    expect(columnIds(tester), contains('dived'));
    final asDived = tester.widget<FilterChip>(chip('As dived'));
    expect(asDived.selected, isTrue);
    expect(asDived.isEnabled, isTrue);
  });

  testWidgets('the read-only chart has no zoom controls', (tester) async {
    await pump(tester, comparison: _comparison());

    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.byType(ChartZoomControls), findsNothing);
  });

  testWidgets('the empty state offers both ways in', (tester) async {
    await pump(tester);

    expect(find.text('Nothing to compare yet'), findsOneWidget);
    expect(find.text('Ask a what-if'), findsOneWidget);
    expect(find.text('Link a plan'), findsOneWidget);
    expect(find.byType(CompareTable), findsNothing);
  });

  testWidgets('a dive with what-ifs and no plan can still link one', (
    tester,
  ) async {
    await pump(tester, scenarios: [_scenario('s1', 'Slower', DateTime(2026))]);

    expect(find.text('Link a plan'), findsOneWidget);
    expect(find.text('Nothing to compare yet'), findsNothing);
  });

  testWidgets('a linked dive that cannot branch has no what-if controls', (
    tester,
  ) async {
    await pump(
      tester,
      dive: Dive(id: _diveId, diveNumber: 1, dateTime: DateTime.utc(2026)),
      comparison: _comparison(),
    );

    expect(chip('Planned'), findsOneWidget);
    expect(find.text('What if'), findsNothing);
    expect(find.byType(DiveProfileChart), findsNothing);
    expect(find.byType(CompareTable), findsOneWidget);
  });

  testWidgets('a planned dive reads Waiting for the dive and nothing else', (
    tester,
  ) async {
    await pump(
      tester,
      dive: Dive(
        id: _diveId,
        dateTime: DateTime.utc(2026),
        isPlanned: true,
        profile: _profile(),
      ),
      comparison: _comparison(),
    );

    expect(find.text('Waiting for the dive'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(CompareTable), findsNothing);
    expect(find.text('Ask a what-if'), findsNothing);
    expect(find.text('Link a plan'), findsNothing);
  });

  testWidgets('a planned dive with no plan can still link one', (tester) async {
    await pump(
      tester,
      dive: Dive(
        id: _diveId,
        dateTime: DateTime.utc(2026),
        isPlanned: true,
        profile: _profile(),
      ),
    );

    expect(find.text('Waiting for the dive'), findsOneWidget);
    expect(find.text('Link a plan'), findsOneWidget);
  });

  testWidgets('tapping the title opens the Compare page', (tester) async {
    await pump(tester, comparison: _comparison());

    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();

    expect(find.byType(DiveLabPage), findsOneWidget);
  });

  testWidgets('tapping the chart opens the Compare page', (tester) async {
    await pump(tester, comparison: _comparison());

    await tester.tap(find.byKey(const ValueKey('compareChart')));
    await tester.pumpAndSettle();

    expect(find.byType(DiveLabPage), findsOneWidget);
  });

  testWidgets('the chart marks where the dive ran out of NDL', (tester) async {
    await pump(
      tester,
      comparison: _comparison(),
      dived: const CompareColumn(
        id: 'dived',
        kind: CompareLineKind.asDived,
        decoStartSeconds: 840,
      ),
    );
    expect(
      tester
          .widget<DiveProfileChart>(find.byType(DiveProfileChart))
          .highlightedTimestamp,
      840,
    );
  });

  testWidgets('the table sits beside the chart when there is room', (
    tester,
  ) async {
    await pump(tester, comparison: _comparison(), width: 1000);

    final chart = tester.getRect(find.byKey(const ValueKey('compareChart')));
    final table = tester.getRect(find.byType(CompareTable));
    expect(table.left, greaterThanOrEqualTo(chart.right));
    expect(table.top, lessThan(chart.bottom));
  });

  group('live', () {
    late db.AppDatabase database;
    late DivePlanRepository repository;

    setUp(() async {
      database = await setUpTestDatabase();
      repository = DivePlanRepository();
    });
    tearDown(tearDownTestDatabase);

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpLive(WidgetTester tester) async {
      await tester.runAsync(() async {
        await database
            .into(database.dives)
            .insert(
              const db.DivesCompanion(
                id: Value(_diveId),
                diveDateTime: Value(1000),
                createdAt: Value(1000),
                updatedAt: Value(1000),
              ),
            );
        await repository.savePlan(_plan().copyWith(linkedDiveId: _diveId));
      });
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            diveProvider.overrideWith(
              (ref, id) async =>
                  Dive(id: _diveId, dateTime: DateTime.utc(2026)),
            ),
            divedColumnProvider.overrideWith((ref, id) async => _dived),
            diveScenariosForDiveProvider.overrideWith(
              (ref, id) async => const <DiveScenario>[],
            ),
          ],
          locale: const Locale('en'),
          child: const SingleChildScrollView(
            child: CompareSection(diveId: _diveId),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('a what-if header opens that what-if', (tester) async {
      await pump(
        tester,
        scenarios: [_scenario('s1', 'Slower', DateTime(2026))],
      );

      await tester.tap(
        find.descendant(
          of: find.byType(CompareTable),
          matching: find.text('Slower'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<DiveLabPage>(find.byType(DiveLabPage)).scenarioId,
        's1',
      );
    });

    testWidgets('Planned leaves when the plan is deleted', (tester) async {
      await pumpLive(tester);
      expect(chip('Planned'), findsOneWidget);

      await tester.runAsync(() => repository.deletePlan('plan-1'));
      await settle(tester);

      expect(chip('Planned'), findsNothing);
    });

    testWidgets('Planned leaves when the link is cleared', (tester) async {
      await pumpLive(tester);
      expect(chip('Planned'), findsOneWidget);

      await tester.runAsync(() => repository.unlinkPlan('plan-1'));
      await settle(tester);

      expect(chip('Planned'), findsNothing);
    });
  });
}
