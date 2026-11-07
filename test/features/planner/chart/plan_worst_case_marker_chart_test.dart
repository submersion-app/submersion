import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/chart/plan_worst_case_marker_layer.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_worst_case_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/planner_results.dart';
import '../../../helpers/test_app.dart';

const _marker = Key('planChartWorstCaseMarker');
const _card = Key('planChartWorstCaseCard');

const _worstCase = PlanChartWorstCase(
  runtimeSeconds: 1200,
  depthMeters: 30,
  ttsSeconds: 900,
  litersRequired: 1500,
  availableLiters: 2000,
  sufficient: true,
  stale: false,
);

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    PlanChartWorstCase? worstCase = _worstCase,
    bool overrideWorstCase = true,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          planResultsSettleDelayProvider.overrideWithValue(Duration.zero),
          planResultRunnerProvider.overrideWithValue(
            const InlinePlanResultRunner(),
          ),
          if (overrideWorstCase)
            planChartWorstCaseProvider.overrideWithValue(worstCase),
        ],
        child: const SizedBox(
          width: 760,
          height: 400,
          child: PlanProfileChart(),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();
    return container;
  }

  Offset pill(WidgetTester tester) {
    final painter =
        tester.widget<CustomPaint>(find.byKey(_marker)).painter
            as PlanWorstCaseMarkerPainter;
    return tester.getTopLeft(find.byType(PlanProfileChart)) +
        painter.placed.pill.center;
  }

  testWidgets('no worst case, no marker', (tester) async {
    await mount(tester, worstCase: null);
    expect(find.byKey(_marker), findsNothing);
  });

  testWidgets('a worst case is marked on the line, its card closed', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byKey(_marker), findsOneWidget);
    expect(find.byKey(_card), findsNothing);
  });

  testWidgets('a tap on the pill pins the card; a second tap lets go', (
    tester,
  ) async {
    final container = await mount(tester);
    final selectedBefore = container.read(selectedSegmentIdProvider);

    await tester.tapAt(pill(tester));
    await tester.pumpAndSettle();
    expect(find.byKey(_card), findsOneWidget);
    expect(find.textContaining('Worst case at 20′'), findsOneWidget);
    // A tap on the pill is not a segment tap.
    expect(container.read(selectedSegmentIdProvider), selectedBefore);

    await tester.tapAt(pill(tester));
    await tester.pumpAndSettle();
    expect(find.byKey(_card), findsNothing);
  });

  testWidgets('a tap elsewhere on the chart lets go of the card', (
    tester,
  ) async {
    await mount(tester);
    await tester.tapAt(pill(tester));
    await tester.pumpAndSettle();
    expect(find.byKey(_card), findsOneWidget);

    final rect = tester.getRect(find.byType(PlanProfileChart));
    await tester.tapAt(rect.bottomRight - const Offset(30, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(_card), findsNothing);
  });

  testWidgets('hovering the pill shows the card instead of scrubbing', (
    tester,
  ) async {
    final container = await mount(tester);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(pill(tester));
    await tester.pump();
    expect(find.byKey(_card), findsOneWidget);
    expect(container.read(scrubTimeProvider), isNull);

    await gesture.moveTo(tester.getTopLeft(find.byType(PlanProfileChart)));
    await tester.pump();
    expect(find.byKey(_card), findsNothing);
  });

  group('with a real bailout result', () {
    Future<ProviderContainer> mountCcr(WidgetTester tester) async {
      final container = await mount(tester, overrideWorstCase: false);
      container.read(divePlanNotifierProvider.notifier)
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
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('an open-circuit plan has no marker', (tester) async {
      await mount(tester, overrideWorstCase: false);
      expect(find.byKey(_marker), findsNothing);
    });

    testWidgets('a loop plan is marked in the CCR view', (tester) async {
      final container = await mountCcr(tester);
      expect(container.read(planChartWorstCaseProvider), isNotNull);
      expect(find.byKey(_marker), findsOneWidget);
    });

    testWidgets('and in the Bailout view, at the same instant', (tester) async {
      final container = await mountCcr(tester);

      container.read(chartDisplayModeProvider.notifier).state =
          ChartDisplayMode.bailout;
      await tester.pumpAndSettle();

      expect(find.byKey(_marker), findsOneWidget);
      final painter =
          tester.widget<CustomPaint>(find.byKey(_marker)).painter
              as PlanWorstCaseMarkerPainter;
      final worstCase = container.read(planChartWorstCaseProvider)!;
      expect(painter.placed.worstCase.runtimeSeconds, worstCase.runtimeSeconds);
      // On the bailout picture the loop leg ends at the worst-case instant,
      // so the diamond sits where the OC ascent begins.
      final series = container.read(planCanvasSeriesProvider);
      expect(
        series.depthAt(worstCase.runtimeSeconds.toDouble()),
        closeTo(worstCase.depthMeters, 0.01),
      );
    });
  });
}
