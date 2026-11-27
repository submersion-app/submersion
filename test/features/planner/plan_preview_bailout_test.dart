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
  const child = SizedBox.shrink();
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
  for (final listener in [
    container.listen(planPreviewBailoutProvider, (_, _) {}),
    container.listen(planShownBailoutProvider, (_, _) {}),
    container.listen(planChartBailoutPreviewProvider, (_, _) {}),
    container.listen(planBailoutProvider, (_, _) {}),
  ]) {
    addTearDown(listener.close);
  }
  loadPlan(container, plan);
  if (bailoutView) {
    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
  }
  await tester.pumpAndSettle();
  return container;
}

double _depthDelta(ProviderContainer container) =>
    container.read(resolvedPlanEngineConfigProvider).deviationDepthDelta;

void main() {
  testWidgets('+5 m bails out from the deeper bottom', (tester) async {
    final container = await _mount(tester, _plan());
    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();

    final base = planResultView(container.read(planBailoutProvider), 'figures');
    final preview = planResultView(
      container.read(planPreviewBailoutProvider),
      'figures',
    );
    expect(
      preview.value!.worstCase.depthMeters,
      closeTo(base.value!.worstCase.depthMeters + _depthDelta(container), 0.01),
    );
  });

  testWidgets('no deviation, no preview bailout', (tester) async {
    final container = await _mount(tester, _plan());

    final preview = planResultView(
      container.read(planPreviewBailoutProvider),
      'figures',
    );
    expect(preview.isFinishedEmpty, isTrue);
  });

  testWidgets('an OC plan has no preview bailout', (tester) async {
    final container = await _mount(
      tester,
      _plan().copyWith(mode: domain.PlanMode.oc),
    );
    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();

    final preview = planResultView(
      container.read(planPreviewBailoutProvider),
      'figures',
    );
    expect(preview.value, isNull);
  });

  testWidgets('the shown bailout follows the deviation', (tester) async {
    final container = await _mount(tester, _plan());
    final base = planResultView(container.read(planBailoutProvider), 'figures');
    expect(container.read(planShownBailoutProvider).value, same(base.value));

    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();
    final preview = planResultView(
      container.read(planPreviewBailoutProvider),
      'figures',
    );
    expect(container.read(planShownBailoutProvider).value, same(preview.value));
  });

  testWidgets('the chart preview needs Bailout view', (tester) async {
    final container = await _mount(tester, _plan());
    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();
    expect(container.read(planChartBailoutPreviewProvider).picture, isNull);

    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
    await tester.pumpAndSettle();
    expect(container.read(planChartBailoutPreviewProvider).picture, isNotNull);
  });
}
