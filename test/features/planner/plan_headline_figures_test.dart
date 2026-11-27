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
import 'package:submersion/features/planner/presentation/providers/plan_headline_figures.dart';
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
  final listener = container.listen(planHeadlineFiguresProvider, (_, _) {});
  addTearDown(listener.close);
  loadPlan(container, plan);
  if (bailoutView) {
    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
  }
  await tester.pumpAndSettle();
  return container;
}

int _decoOf(BailoutOutcome bailout) => bailout.ocStops
    .where((s) => !s.isGasSwitchOnly)
    .fold(0, (sum, s) => sum + s.durationSeconds);

void main() {
  testWidgets("the plan's figures outside Bailout view", (tester) async {
    final container = await _mount(tester, _plan());

    final figures = container.read(planHeadlineFiguresProvider);
    final outcome = container.read(activePlanOutcomeProvider);
    expect(figures.runtimeSeconds, outcome.runtimeSeconds);
    expect(figures.ndlSeconds, outcome.ndlAtBottom);
    expect(figures.owesDecompression, outcome.owesDecompression);
    expect(figures.ttsSeconds, outcome.ttsAtBottom);
    expect(figures.decoSeconds, outcome.totalDecoSeconds);
    expect(figures.cnsEnd, outcome.cnsEnd);
    expect(figures.isBailout, isFalse);
    expect(figures.stale, isFalse);
  });

  testWidgets("the bailout's figures while the chart draws it", (tester) async {
    final container = await _mount(tester, _plan(), bailoutView: true);

    final picture = container.read(planChartBailoutProvider).picture!;
    final worst = picture.worstCase;
    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.runtimeSeconds, worst.runtimeSeconds + worst.ttsSeconds);
    expect(figures.ttsSeconds, worst.ttsSeconds);
    expect(figures.decoSeconds, _decoOf(picture));
    expect(figures.decoSeconds, greaterThan(0));
    expect(figures.cnsEnd, picture.worstCaseCnsEnd);
    expect(figures.ndlSeconds, -1);
    expect(figures.owesDecompression, isTrue);
    expect(figures.isBailout, isTrue);
    expect(figures.stale, isFalse);
  });

  testWidgets('a bailout with no stops still shows its TTS', (tester) async {
    final container = await _mount(
      tester,
      _plan(depth: 12, minutes: 20),
      bailoutView: true,
    );

    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.isBailout, isTrue);
    expect(figures.decoSeconds, 0);
    expect(figures.ndlSeconds, -1);
    expect(figures.ttsSeconds, greaterThan(0));
  });

  testWidgets("a gas gap keeps the plan's figures", (tester) async {
    final container = await _mount(
      tester,
      _plan(depth: 30, bailout: const GasMix(o2: 50)),
      bailoutView: true,
    );

    expect(container.read(planChartBailoutProvider).gasGap, isNotNull);
    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.isBailout, isFalse);
    expect(
      figures.runtimeSeconds,
      container.read(activePlanOutcomeProvider).runtimeSeconds,
    );
  });

  testWidgets('figures still updating are stale', (tester) async {
    final picture = const BailoutSolver().solve(_plan())!;
    final container = await _mount(
      tester,
      _plan(),
      overrides: [
        planChartBailoutProvider.overrideWith(
          (ref) => (
            picture: picture,
            status: PlanResultStatus.updating,
            gasGap: null,
          ),
        ),
      ],
    );

    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.isBailout, isTrue);
    expect(figures.stale, isTrue);
    expect(figures.cnsEnd, picture.worstCaseCnsEnd);
  });

  testWidgets("an OC plan keeps the plan's figures in Bailout view", (
    tester,
  ) async {
    final container = await _mount(
      tester,
      _plan().copyWith(mode: domain.PlanMode.oc),
      bailoutView: true,
    );

    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.isBailout, isFalse);
    expect(
      figures.runtimeSeconds,
      container.read(activePlanOutcomeProvider).runtimeSeconds,
    );
  });

  testWidgets("a failed bailout run keeps the plan's figures", (tester) async {
    final container = await _mount(
      tester,
      _plan(),
      overrides: [
        planChartBailoutProvider.overrideWith(
          (ref) =>
              (picture: null, status: PlanResultStatus.failed, gasGap: null),
        ),
      ],
    );

    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.isBailout, isFalse);
    expect(figures.stale, isFalse);
    expect(figures.cnsEnd, container.read(activePlanOutcomeProvider).cnsEnd);
  });
}
