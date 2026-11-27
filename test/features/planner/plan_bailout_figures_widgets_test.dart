import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';
import 'package:submersion/features/planner/presentation/panes/plan_results_pane.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_headline_figures.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_chart_readouts.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';
import '../../helpers/test_app.dart';

const _air = GasMix(o2: 21);
final _l10n = AppLocalizationsEn();

/// A CCR dive on air diluent at [depth] for 25 minutes, bailing out to
/// [bailout].
domain.DivePlan _plan({double depth = 40, GasMix bailout = _air}) =>
    domain.DivePlan(
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
          durationMinutes: 25,
          tankId: 'dil',
          gasMix: _air,
          order: 1,
        ),
      ],
    );

Future<ProviderContainer> _mount(
  WidgetTester tester,
  Widget child, {
  domain.DivePlan? plan,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...plannerResultsInline(),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ...overrides,
      ],
      child: Scaffold(body: child),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byWidget(child)),
  );
  loadPlan(container, plan ?? _plan());
  container.read(chartDisplayModeProvider.notifier).state =
      ChartDisplayMode.bailout;
  await tester.pumpAndSettle();
  return container;
}

String _minutes(int seconds) => '${(seconds / 60).ceil()}′';

Widget get _readouts => Stack(
  children: [
    const Positioned.fill(child: ColoredBox(color: Colors.black12)),
    PlanChartReadouts(onIssuesTap: () {}),
  ],
);

void main() {
  testWidgets("the phone readouts show the bailout's figures", (tester) async {
    final container = await _mount(tester, _readouts);

    final figures = container.read(planHeadlineFiguresProvider);
    expect(figures.isBailout, isTrue);
    expect(find.text('Runtime'), findsOneWidget);
    expect(find.text('Bailout runtime'), findsNothing);
    expect(find.text(_minutes(figures.runtimeSeconds)), findsOneWidget);
    expect(find.text(_minutes(figures.ttsSeconds)), findsOneWidget);
    expect(find.text(_minutes(figures.decoSeconds)), findsOneWidget);
    expect(
      find.text(
        _l10n.plannerCanvas_chip_cns(figures.cnsEnd.toStringAsFixed(0)),
      ),
      findsOneWidget,
    );
    final issues = container.read(activePlanOutcomeProvider).issues;
    expect(
      find.text(
        _l10n.plannerCanvas_chip_issues(groupPlanIssues(issues).length),
      ),
      findsOneWidget,
    );
  });

  testWidgets("the desktop chips show the bailout's figures", (tester) async {
    final container = await _mount(tester, PlanStatusChips(onIssuesTap: () {}));

    final figures = container.read(planHeadlineFiguresProvider);
    PlanChip chip(String label) => tester.widget<PlanChip>(
      find.byWidgetPredicate((w) => w is PlanChip && w.label == label),
    );
    expect(chip('Runtime').value, _minutes(figures.runtimeSeconds));
    expect(chip('TTS').value, _minutes(figures.ttsSeconds));
    expect(chip('DECO').value, _minutes(figures.decoSeconds));
    expect(
      find.text(
        _l10n.plannerCanvas_chip_cns(figures.cnsEnd.toStringAsFixed(0)),
      ),
      findsOneWidget,
    );
  });

  testWidgets("the Results tiles show the bailout's figures", (tester) async {
    final container = await _mount(
      tester,
      PlanResultsPane(controller: ScrollController()),
    );

    final figures = container.read(planHeadlineFiguresProvider);
    String rounded(int seconds) => "${(seconds / 60).round()}'";
    PlanStatTile tile(String label) => tester.widget<PlanStatTile>(
      find.byWidgetPredicate((w) => w is PlanStatTile && w.label == label),
    );
    expect(tile('Runtime').value, rounded(figures.runtimeSeconds));
    expect(tile('TTS').value, rounded(figures.ttsSeconds));
    expect(tile('CNS').value, '${figures.cnsEnd.round()}%');
    final issues = container.read(activePlanOutcomeProvider).issues;
    expect(tile('Warnings').value, '${groupPlanIssues(issues).length}');
  });

  testWidgets("without a picture the figures stay the plan's", (tester) async {
    final container = await _mount(
      tester,
      _readouts,
      plan: _plan(depth: 30, bailout: const GasMix(o2: 50)),
    );

    expect(container.read(planChartBailoutProvider).gasGap, isNotNull);
    final outcome = container.read(activePlanOutcomeProvider);
    expect(find.text(_minutes(outcome.runtimeSeconds)), findsOneWidget);
    expect(find.text('Runtime'), findsOneWidget);
  });

  Finder halfOpacityAbove(Finder child) => find.ancestor(
    of: child,
    matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.5),
  );

  testWidgets('fresh bailout figures are not dimmed', (tester) async {
    await _mount(tester, _readouts);

    expect(halfOpacityAbove(find.text('Runtime')), findsNothing);
    expect(halfOpacityAbove(find.text('TTS')), findsNothing);
  });

  testWidgets('stale bailout figures are dimmed on the desktop chips too', (
    tester,
  ) async {
    final picture = const BailoutSolver().solve(_plan())!;
    await _mount(
      tester,
      PlanStatusChips(onIssuesTap: () {}),
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

    expect(halfOpacityAbove(find.text('Runtime')), findsOneWidget);
    expect(halfOpacityAbove(find.text('TTS')), findsOneWidget);
    expect(halfOpacityAbove(find.textContaining('issue')), findsNothing);
  });

  testWidgets('stale bailout figures are dimmed', (tester) async {
    final picture = const BailoutSolver().solve(_plan())!;
    await _mount(
      tester,
      _readouts,
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

    final dimmed = find.ancestor(
      of: find.text('Runtime'),
      matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.5),
    );
    expect(dimmed, findsOneWidget);
  });
}
