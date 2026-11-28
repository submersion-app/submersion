import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_issue_markers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_issue_marker_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/chart_mode_toggle.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';
import '../../helpers/test_app.dart';

const _air = GasMix(o2: 21);

/// A 40 m CCR dive on air, which warns about its END, with an air bailout
/// that covers it.
final _plan = domain.DivePlan(
  id: 'switch',
  name: 'Switch',
  mode: domain.PlanMode.ccr,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  tanks: const [
    DiveTank(
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
      gasMix: _air,
      role: TankRole.bailout,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: 40,
      ratePerMinute: 18,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 40,
      durationMinutes: 25,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

Future<ProviderContainer> _mount(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...plannerResultsInline(),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: Center(child: child),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byWidget(child)),
  );
  loadPlan(container, _plan);
  await tester.pumpAndSettle();
  return container;
}

Finder get _bailoutChip => find.descendant(
  of: find.byType(ChartModeToggle),
  matching: find.byType(PlanChip),
);

void main() {
  testWidgets('Bailout is one chip, and the plan view has none', (
    tester,
  ) async {
    await _mount(tester, const ChartModeToggle());

    expect(_bailoutChip, findsOneWidget);
    expect(find.text('Bailout'), findsOneWidget);
    expect(find.text('CCR'), findsNothing);
    expect(tester.widget<PlanChip>(_bailoutChip).emphasized, isFalse);
  });

  testWidgets('tapping it turns the Bailout view on, and off again', (
    tester,
  ) async {
    final container = await _mount(tester, const ChartModeToggle());

    await tester.tap(find.text('Bailout'));
    await tester.pumpAndSettle();
    expect(container.read(chartDisplayModeProvider), ChartDisplayMode.bailout);
    expect(tester.widget<PlanChip>(_bailoutChip).emphasized, isTrue);

    await tester.tap(find.text('Bailout'));
    await tester.pumpAndSettle();
    expect(container.read(chartDisplayModeProvider), ChartDisplayMode.ccr);
    expect(tester.widget<PlanChip>(_bailoutChip).emphasized, isFalse);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('it is as tall as the contingency chips beside it, at text '
        'scale $scale', (tester) async {
      await _mount(
        tester,
        MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [ContingencyChips(), ChartModeToggle()],
          ),
        ),
      );

      final base = find.descendant(
        of: find.byType(ContingencyChips),
        matching: find.byType(PlanChip),
      );
      expect(
        tester.getSize(_bailoutChip).height,
        tester.getSize(base.first).height,
      );
    });
  }

  Finder scrimsAbove(Finder child) => find.ancestor(
    of: child,
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color != null,
    ),
  );

  testWidgets('on the chart it sits on a scrim of its own', (tester) async {
    await _mount(tester, const ChartModeToggle(overlay: true));

    // The chip's own fill, and the scrim round it.
    expect(scrimsAbove(find.text('Bailout')), findsNWidgets(2));
  });

  testWidgets('off the chart it has no scrim', (tester) async {
    await _mount(tester, const ChartModeToggle());

    expect(scrimsAbove(find.text('Bailout')), findsOneWidget);
  });

  group('the contingencies in Bailout view', () {
    Finder contingencyChips() => find.descendant(
      of: find.byType(ContingencyChips),
      matching: find.byType(PlanChip),
    );

    testWidgets('combine with Bailout', (tester) async {
      final container = await _mount(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [ContingencyChips(), ChartModeToggle()],
        ),
      );
      await tester.tap(find.text('Bailout'));
      await tester.pumpAndSettle();

      for (final chip in contingencyChips().evaluate()) {
        final opacity = find.ancestor(
          of: find.byWidget(chip.widget),
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(opacity.first).opacity, 1);
      }
      await tester.tap(contingencyChips().at(1));
      await tester.pumpAndSettle();
      expect(container.read(contingencySelectionProvider).deeper, isTrue);
      expect(
        container.read(chartDisplayModeProvider),
        ChartDisplayMode.bailout,
      );
    });

    testWidgets("preview the deviated dive's bailout, not the plan's", (
      tester,
    ) async {
      final container = await _mount(tester, const ChartModeToggle());
      // Held as the chart holds it, so the preview bailout is worked out.
      final ghost = container.listen(contingencyGhostSeriesProvider, (_, _) {});
      addTearDown(ghost.close);
      container.read(contingencySelectionProvider.notifier).toggleDeeper();
      await tester.pumpAndSettle();
      final planGhost = container.read(contingencyGhostSeriesProvider)!;

      await tester.tap(find.text('Bailout'));
      await tester.pumpAndSettle();
      final delta = container
          .read(resolvedPlanEngineConfigProvider)
          .deviationDepthDelta;
      expect(container.read(selectedContingencyProvider), isNull);
      expect(
        container.read(contingencyGhostSeriesProvider)!.maxDepth,
        closeTo(
          container.read(planCanvasSeriesProvider).maxDepth + delta,
          0.01,
        ),
      );

      await tester.tap(find.text('Bailout'));
      await tester.pumpAndSettle();
      expect(container.read(selectedContingencyProvider), isNotNull);
      expect(
        container.read(contingencyGhostSeriesProvider)!.maxDepth,
        planGhost.maxDepth,
      );
    });

    testWidgets('come back when the Bailout chip goes with the last bailout '
        'tank', (tester) async {
      final container = await _mount(tester, const ChartModeToggle());
      container.read(contingencySelectionProvider.notifier).toggleDeeper();
      await tester.tap(find.text('Bailout'));
      await tester.pumpAndSettle();
      expect(container.read(selectedContingencyProvider), isNull);

      container.read(divePlanNotifierProvider.notifier).removeTank('bo');
      await tester.pumpAndSettle();

      expect(find.text('Bailout'), findsNothing);
      expect(container.read(selectedContingencyProvider), isNotNull);
    });

    testWidgets('a row picked in the results toggles it in Bailout view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await _mount(
        tester,
        SizedBox(
          width: 500,
          height: 2400,
          child: PlanResultsSheet(controller: ScrollController()),
        ),
      );
      container.read(contingenciesExpandedProvider.notifier).state = true;
      container.read(chartDisplayModeProvider.notifier).state =
          ChartDisplayMode.bailout;
      await tester.pumpAndSettle();

      final deeperRow = find.byWidgetPredicate(
        (w) =>
            w is PlanChip && w.label.startsWith('+') && !w.label.contains('′'),
      );
      await tester.ensureVisible(deeperRow.first);
      await tester.tap(deeperRow.first);
      await tester.pumpAndSettle();

      expect(
        container.read(chartDisplayModeProvider),
        ChartDisplayMode.bailout,
      );
      expect(container.read(contingencySelectionProvider).deeper, isTrue);
    });
  });

  group('the warning markers', () {
    testWidgets('are hidden while the bailout picture is drawn', (
      tester,
    ) async {
      final container = await _mount(tester, const ChartModeToggle());
      expect(container.read(planIssueMarkersProvider), isNotEmpty);

      await tester.tap(find.text('Bailout'));
      await tester.pumpAndSettle();

      expect(container.read(planChartBailoutProvider).picture, isNotNull);
      expect(container.read(planIssueMarkersProvider), isEmpty);
    });

    testWidgets('show while the chart draws the plan in Bailout view', (
      tester,
    ) async {
      final container = await _mount(tester, const ChartModeToggle());
      expect(container.read(planIssueMarkersProvider), isNotEmpty);
      await tester.tap(find.text('Bailout'));
      await tester.pumpAndSettle();

      container.read(divePlanNotifierProvider.notifier).removeTank('bo');
      await tester.pumpAndSettle();

      expect(
        container.read(chartDisplayModeProvider),
        ChartDisplayMode.bailout,
      );
      expect(container.read(planChartBailoutProvider).picture, isNull);
      List<int> at(List<PlanIssueMarker> markers) => [
        for (final m in markers) m.runtimeSeconds,
      ];
      final shown = container.read(planIssueMarkersProvider);
      expect(shown, isNotEmpty);
      expect(
        at(shown),
        at(planIssueMarkers(container.read(activePlanOutcomeProvider).issues)),
      );
    });
  });
}
