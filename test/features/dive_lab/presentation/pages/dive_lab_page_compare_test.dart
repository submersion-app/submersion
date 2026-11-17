import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/compare_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_table.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_chart.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_runtime_table.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

const _air = GasMix(o2: 21);

/// What the inputs depend on: a change reloads them, keeping the old value.
final _inputsSource = StateProvider<int>((_) => 0);

domain.DivePlan _plan({String? linkedDiveId}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Wreck',
  gfLow: 30,
  gfHigh: 70,
  linkedDiveId: linkedDiveId,
  tanks: const [
    DiveTank(id: 'tank-1', volume: 24, startPressure: 220, gasMix: _air),
  ],
  segments: [
    PlanSegment.travel(
      id: 'seg-1',
      fromDepth: 0,
      targetDepth: 45,
      tankId: 'tank-1',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'seg-2',
      depth: 45,
      durationMinutes: 28,
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
  final outcome = const PlanEngine().compute(plan);
  return LinkedPlanComparison(
    plan: plan,
    outcome: outcome,
    overlay: buildPlannedOverlay(plan, outcome: outcome),
  );
}

LabRequestInputs _inputs({bool isPlanned = false}) {
  final d = squareDive(depth: 45, bottomMinutes: 30);
  return LabRequestInputs(
    dive: Dive(
      id: 'd',
      diveNumber: 1,
      dateTime: DateTime(2026),
      isPlanned: isPlanned,
    ),
    profile: [
      for (var i = 0; i < d.depths.length; i++)
        DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
    ],
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: DiveMode.oc,
    tanks: d.tanks,
    gasSwitches: d.switches,
    tankPressures: d.tankPressures,
    startCns: 0,
    startOtu: 0,
    settings: const ScenarioSettings(),
  );
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    LabRequestInputs? inputs,
    LinkedPlanComparison? comparison,
    Dive? dive,
    Size size = const Size(420, 2200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final shown =
        dive ??
        inputs?.dive ??
        Dive(id: 'd', diveNumber: 1, dateTime: DateTime(2026));
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          labRequestInputsProvider('d').overrideWith((ref) async {
            // A reload stays in flight long enough to be looked at.
            if (ref.watch(_inputsSource) > 0) {
              await Future<void>.delayed(const Duration(seconds: 1));
            }
            return inputs;
          }),
          labDefaultBranchProvider('d').overrideWith((ref) async => 900),
          scenarioEngineRunnerProvider.overrideWithValue(
            (request) async => const ScenarioEngine().run(request),
          ),
          linkedPlanComparisonProvider.overrideWith(
            (ref, id) async => comparison,
          ),
          diveProvider.overrideWith((ref, id) async => shown),
          diveProfileProvider.overrideWith((ref, id) async => shown.profile),
          divedColumnProvider.overrideWith(
            (ref, id) async => const CompareColumn(
              id: 'dived',
              kind: CompareLineKind.asDived,
              maxDepthMeters: 44,
            ),
          ),
        ],
        locale: const Locale('en'),
        child: const DiveLabPage(diveId: 'd'),
      ),
    );
    await settle(tester);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  Finder plannedChip() => find.widgetWithText(FilterChip, 'Planned');

  testWidgets('the Planned chip and line appear with a link', (tester) async {
    await pump(tester, inputs: _inputs(), comparison: _comparison());

    expect(plannedChip(), findsOneWidget);
    // Named as its chip is, not after the plan, so the legend reads
    // "Depth · Planned" beside the dive's own depth (#4215).
    expect(
      tester.widget<LabChart>(find.byType(LabChart)).planOverlay?.name,
      'Planned',
    );
  });

  testWidgets('the app bar actions stay through a reload', (tester) async {
    await pump(tester, inputs: _inputs(), comparison: _comparison());
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveLabPage)),
    );
    container.read(_inputsSource.notifier).state++;
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
  });

  testWidgets('with no link there is no Planned anything', (tester) async {
    await pump(tester, inputs: _inputs());

    expect(plannedChip(), findsNothing);
    expect(tester.widget<LabChart>(find.byType(LabChart)).planOverlay, isNull);
    expect(find.byType(CompareTable), findsNothing);
    expect(find.text('PLANNED SCHEDULE'), findsNothing);
  });

  testWidgets('the chip hides the line, the table and the schedule', (
    tester,
  ) async {
    await pump(tester, inputs: _inputs(), comparison: _comparison());

    await tester.tap(plannedChip());
    await settle(tester);

    expect(tester.widget<LabChart>(find.byType(LabChart)).planOverlay, isNull);
    expect(find.byType(CompareTable), findsNothing);
    expect(find.text('PLANNED SCHEDULE'), findsNothing);
  });

  testWidgets('the Planned table sits above the delta table', (tester) async {
    await pump(tester, inputs: _inputs(), comparison: _comparison());

    final table = tester.widget<CompareTable>(find.byType(CompareTable));
    expect(table.columns.map((c) => c.kind), [
      CompareLineKind.planned,
      CompareLineKind.asDived,
      CompareLineKind.whatIf,
    ]);
    expect(
      tester.getTopLeft(find.byType(CompareTable)).dy,
      lessThan(tester.getTopLeft(find.text('Delta').first).dy),
    );
  });

  testWidgets('the what-if column has a heading with no saved name', (
    tester,
  ) async {
    await pump(tester, inputs: _inputs(), comparison: _comparison());

    expect(
      find.descendant(
        of: find.byType(CompareTable),
        matching: find.text('What if'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the plan\'s schedule shows in its own table', (tester) async {
    final comparison = _comparison();
    await pump(tester, inputs: _inputs(), comparison: comparison);

    expect(find.text('PLANNED SCHEDULE'), findsOneWidget);
    final tables = tester.widgetList<LabRuntimeTable>(
      find.byType(LabRuntimeTable),
    );
    expect(tables.any((t) => identical(t.outcome, comparison.outcome)), isTrue);
  });
  // The dive's plan link is changed on its Compare card, held until Save
  // (issue #4527).
  testWidgets('the menu offers no plan link', (tester) async {
    await pump(tester, inputs: _inputs(), comparison: _comparison());
    await openMenu(tester);

    expect(find.text('Link a plan'), findsNothing);
    expect(find.text('Unlink plan'), findsNothing);
    expect(find.text('Share PDF slate'), findsOneWidget);
  });

  testWidgets('a linked dive that cannot branch shows the plan alone', (
    tester,
  ) async {
    await pump(
      tester,
      comparison: _comparison(),
      dive: Dive(
        id: 'd',
        dateTime: DateTime(2026),
        diveMode: DiveMode.gauge,
        profile: _inputs().profile,
      ),
    );

    expect(find.byType(CompareTable), findsOneWidget);
    expect(find.text('PLANNED SCHEDULE'), findsOneWidget);
    expect(
      tester
          .widget<DiveProfileChart>(find.byType(DiveProfileChart))
          .overlays
          ?.map((o) => o.name),
      ['Planned'],
    );
    expect(find.text('Replay'), findsNothing);
    expect(find.text('Add'), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsNothing);
    expect(find.byIcon(Icons.folder_open_outlined), findsNothing);

    // Nothing to share or open in the planner, and the plan link is
    // changed on the dive's Compare card: no menu at all.
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('a profile-less linked dive shows the plan', (tester) async {
    await pump(tester, comparison: _comparison());

    expect(find.byType(CompareTable), findsOneWidget);
    expect(find.byType(LabChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dive with no link and no branch keeps its message', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(CompareTable), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('a planned dive reads Waiting for the dive', (tester) async {
    await pump(
      tester,
      inputs: _inputs(isPlanned: true),
      comparison: _comparison(),
    );

    expect(find.text('Waiting for the dive'), findsOneWidget);
    expect(find.byType(LabChart), findsNothing);
    expect(find.text('Replay'), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsNothing);
  });
}
