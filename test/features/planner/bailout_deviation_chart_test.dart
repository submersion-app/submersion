import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_headline_figures.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
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
  final child = Column(
    children: [
      const PlanChartBailoutStatus(),
      PlanStatusChips(onIssuesTap: () {}),
    ],
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
  for (final listener in [
    container.listen(planHeadlineFiguresProvider, (_, _) {}),
    container.listen(contingencyGhostSeriesProvider, (_, _) {}),
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

double _delta(ProviderContainer container) =>
    container.read(resolvedPlanEngineConfigProvider).deviationDepthDelta;

Future<ProviderContainer> _deeperInBailoutView(
  WidgetTester tester,
  domain.DivePlan plan,
) async {
  final container = await _mount(tester, plan, bailoutView: true);
  container.read(contingencySelectionProvider.notifier).toggleDeeper();
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('+5 m in Bailout view draws the deeper bailout as the ghost', (
    tester,
  ) async {
    final container = await _deeperInBailoutView(tester, _plan());

    final base = container.read(planCanvasSeriesProvider);
    final ghost = container.read(contingencyGhostSeriesProvider)!;
    expect(ghost.maxDepth, closeTo(base.maxDepth + _delta(container), 0.01));
    final tags = container.read(planChartStopTagsProvider);
    expect(tags, isNotEmpty);
    expect(tags.any((t) => t.change != null || t.isNew), isTrue);
  });

  testWidgets('Previewing shows in Bailout view', (tester) async {
    await _deeperInBailoutView(tester, _plan());

    expect(find.textContaining('Previewing'), findsOneWidget);
  });

  testWidgets('the figures follow the preview bailout', (tester) async {
    final container = await _deeperInBailoutView(tester, _plan());

    final preview = container.read(planChartBailoutPreviewProvider).picture!;
    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.isBailout, isTrue);
    expect(
      figures.runtimeSeconds,
      preview.worstCase.runtimeSeconds + preview.worstCase.ttsSeconds,
    );
    expect(figures.cnsEnd, preview.worstCaseCnsEnd);
  });

  testWidgets('a deviation gas gap says so and keeps the base bailout', (
    tester,
  ) async {
    // EAN32 reaches 40 m: the plan is covered, its +5 m deviation is not.
    final container = await _deeperInBailoutView(
      tester,
      _plan(depth: 37, bailout: const GasMix(o2: 32)),
    );

    final base = container.read(planChartBailoutProvider).picture!;
    expect(container.read(planChartBailoutPreviewProvider).gasGap, isNotNull);
    expect(container.read(contingencyGhostSeriesProvider), isNull);
    expect(find.textContaining('No bailout gas reaches'), findsOneWidget);
    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.cnsEnd, base.worstCaseCnsEnd);
    expect(figures.stale, isFalse);
  });

  testWidgets('a preview still computing keeps the base figures, dimmed', (
    tester,
  ) async {
    final container = await _mount(
      tester,
      _plan(),
      bailoutView: true,
      overrides: [
        planChartBailoutPreviewProvider.overrideWith(
          (ref) => (
            picture: null,
            status: PlanResultStatus.calculating,
            gasGap: null,
          ),
        ),
      ],
    );

    final base = container.read(planChartBailoutProvider).picture!;
    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.cnsEnd, base.worstCaseCnsEnd);
    expect(figures.stale, isTrue);
    expect(find.text('Calculating'), findsOneWidget);
  });

  testWidgets('no preview ghost without the base bailout under it', (
    tester,
  ) async {
    final container = await _mount(
      tester,
      _plan(),
      bailoutView: true,
      overrides: [
        planChartBailoutProvider.overrideWith(
          (ref) => (
            picture: null,
            status: PlanResultStatus.calculating,
            gasGap: null,
          ),
        ),
      ],
    );
    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();

    expect(container.read(planChartBailoutPreviewProvider).picture, isNotNull);
    expect(container.read(contingencyGhostSeriesProvider), isNull);
  });
}
