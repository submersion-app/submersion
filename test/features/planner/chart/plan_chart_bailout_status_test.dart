import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/pages/plan_chart_fullscreen_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/chart_mode_toggle.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/planner_results.dart';
import '../../../helpers/test_app.dart';

const _calculating = 'Calculating';
const _updating = 'Updating';
const _failed = 'Could not be calculated';

void main() {
  late HeldPlanResultRunner runner;

  Finder anchor() => find.byType(PlanProfileChart);

  /// Mounts [child] with a CCR plan in Bailout view, the first bailout run
  /// held.
  Future<ProviderContainer> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    runner = HeldPlanResultRunner();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          planResultsSettleDelayProvider.overrideWithValue(Duration.zero),
          planResultRunnerProvider.overrideWithValue(runner),
        ],
        child: child,
      ),
    );
    final container = ProviderScope.containerOf(tester.element(anchor()));
    container.read(divePlanNotifierProvider.notifier)
      ..addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25)
      ..updateMode(domain.PlanMode.ccr)
      ..addTank(
        const DiveTank(
          id: 'bo',
          volume: 11.1,
          startPressure: 207,
          gasMix: GasMix(o2: 32),
          role: TankRole.bailout,
        ),
      );
    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
    await tester.pump();
    await tester.pump();
    return container;
  }

  Future<void> landLatest(WidgetTester tester) async {
    runner.held.last.finish();
    await tester.pump();
    await tester.pump();
  }

  void edit(ProviderContainer container) {
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final bottom = container.read(divePlanNotifierProvider).segments.last;
    notifier.updateSegment(
      bottom.id,
      bottom.copyWith(durationSeconds: bottom.durationSeconds + 60),
    );
  }

  final charts = <String, Widget>{
    'inline': const SizedBox(
      width: 760,
      height: 400,
      child: PlanProfileChart(),
    ),
    'fullscreen': const PlanChartFullscreenPage(),
  };

  for (final MapEntry(key: name, value: chart) in charts.entries) {
    group('$name chart', () {
      testWidgets('a current result has no label', (tester) async {
        await mount(tester, chart);
        await landLatest(tester);

        expect(find.text(_calculating), findsNothing);
        expect(find.text(_updating), findsNothing);
        expect(find.text(_failed), findsNothing);
      });

      testWidgets('a first result pending says calculating', (tester) async {
        await mount(tester, chart);

        expect(find.text(_calculating), findsOneWidget);
      });

      testWidgets('a newer result pending says updating', (tester) async {
        final container = await mount(tester, chart);
        await landLatest(tester);

        edit(container);
        await tester.pump();

        expect(find.text(_updating), findsOneWidget);
      });

      testWidgets('a failure says so', (tester) async {
        await mount(tester, chart);
        runner.held.last.fail(StateError('engine'));
        await tester.pump();
        await tester.pump();

        expect(find.text(_failed), findsOneWidget);
      });

      testWidgets('removing the last bailout tank leaves no label', (
        tester,
      ) async {
        final container = await mount(tester, chart);
        await landLatest(tester);
        edit(container);
        await tester.pump();
        expect(find.text(_updating), findsOneWidget);

        container.read(divePlanNotifierProvider.notifier).removeTank('bo');
        await tester.pump();

        expect(find.text(_updating), findsNothing);
      });
    });
  }

  testWidgets('on a phone the label stays clear of the scrub readout', (
    tester,
  ) async {
    final container = await mount(
      tester,
      const SizedBox(width: 370, height: 220, child: PlanProfileChart()),
    );
    expect(find.text(_calculating), findsOneWidget);

    container.read(scrubTimeProvider.notifier).state = 600;
    await tester.pump();

    final readout = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_ScrubReadout',
    );
    expect(readout, findsOneWidget);
    final overlap = tester
        .getRect(readout)
        .intersect(tester.getRect(find.byType(PlanChartBailoutStatus)));
    expect(overlap.width <= 0 || overlap.height <= 0, isTrue);
  });

  testWidgets('at a large text size the label stays clear of the readout', (
    tester,
  ) async {
    final container = await mount(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: const SizedBox(
            width: 370,
            height: 220,
            child: PlanProfileChart(),
          ),
        ),
      ),
    );

    container.read(scrubTimeProvider.notifier).state = 600;
    await tester.pump();

    final readout = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_ScrubReadout',
    );
    final overlap = tester
        .getRect(readout)
        .intersect(tester.getRect(find.byType(PlanChartBailoutStatus)));
    expect(overlap.width <= 0 || overlap.height <= 0, isTrue);
  });

  testWidgets('the toggle does not flicker through an edit', (tester) async {
    final container = await mount(
      tester,
      const Column(
        children: [
          ChartModeToggle(),
          SizedBox(width: 760, height: 400, child: PlanProfileChart()),
        ],
      ),
    );
    // Before any result exists the chip already holds its place.
    expect(find.text('Bailout'), findsOneWidget);

    await landLatest(tester);
    expect(find.text('Bailout'), findsOneWidget);

    edit(container);
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      expect(find.text('Bailout'), findsOneWidget);
    }
    await landLatest(tester);
    expect(find.text('Bailout'), findsOneWidget);
  });
}
