import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_worst_case_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';
import '../../helpers/test_app.dart';

const _air = GasMix(o2: 21);

/// A CCR dive on air diluent at [depth] for [minutes], bailing out to
/// [bailout].
domain.DivePlan _plan({
  double depth = 40,
  int minutes = 25,
  GasMix bailout = _air,
}) => domain.DivePlan(
  id: 'figures',
  name: 'Figures',
  mode: domain.PlanMode.ccr,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  tanks: [
    const DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    DiveTank(
      id: 'bo',
      volume: 11.1,
      startPressure: 207,
      gasMix: bailout,
      role: TankRole.bailout,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: depth,
      ratePerMinute: 18,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  domain.DivePlan plan, {
  bool bailoutView = false,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final child = SizedBox(
    width: 500,
    height: 2400,
    child: PlanResultsSheet(controller: ScrollController()),
  );
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...plannerResultsInline(),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ...overrides,
      ],
      child: child,
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byWidget(child)),
  );
  // Held as a widget would hold it, so the bailout result is worked out.
  final listener = container.listen(planChartWorstCaseProvider, (_, _) {});
  addTearDown(listener.close);
  loadPlan(container, plan);
  if (bailoutView) {
    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
  }
  await tester.pumpAndSettle();
  return container;
}

double _delta(ProviderContainer container) =>
    container.read(resolvedPlanEngineConfigProvider).deviationDepthDelta;

void main() {
  testWidgets('the marker follows the deviated bailout', (tester) async {
    final container = await _mount(tester, _plan());
    final base = container.read(planChartWorstCaseProvider)!;

    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();

    expect(
      container.read(planChartWorstCaseProvider)!.depthMeters,
      closeTo(base.depthMeters + _delta(container), 0.01),
    );
  });

  testWidgets('the Results Bailout section shows the deviated bailout', (
    tester,
  ) async {
    final container = await _mount(tester, _plan());
    expect(find.textContaining('· 40m'), findsOneWidget);

    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();

    final deeper = (40 + _delta(container)).round();
    expect(find.textContaining('· ${deeper}m'), findsOneWidget);
    expect(find.textContaining('· 40m'), findsNothing);
  });

  testWidgets(
    "while the deviated bailout is worked out, Results keeps the plan's",
    (tester) async {
      final pending = Completer<PlanBackgroundResult<BailoutOutcome?>>();
      final container = await _mount(
        tester,
        _plan(),
        overrides: [
          planPreviewBailoutProvider.overrideWith((ref) => pending.future),
        ],
      );

      container.read(contingencySelectionProvider.notifier).toggleDeeper();
      await tester.pumpAndSettle();

      expect(find.textContaining('· 40m'), findsOneWidget);
      expect(
        container.read(planShownBailoutProvider).status,
        PlanResultStatus.updating,
      );
    },
  );

  testWidgets(
    "while the deviated bailout is worked out, the plan's worst case is not "
    "marked on the deviated line",
    (tester) async {
      final pending = Completer<PlanBackgroundResult<BailoutOutcome?>>();
      final container = await _mount(
        tester,
        _plan(),
        overrides: [
          planPreviewBailoutProvider.overrideWith((ref) => pending.future),
        ],
      );
      final base = container.read(planChartWorstCaseProvider)!;

      container.read(contingencySelectionProvider.notifier).toggleDeeper();
      await tester.pumpAndSettle();

      final marker = container.read(planChartWorstCaseProvider)!;
      expect(marker.depthMeters, base.depthMeters);
      expect(marker.onDeviation, isFalse);
    },
  );
}
