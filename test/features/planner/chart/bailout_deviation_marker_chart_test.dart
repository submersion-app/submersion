import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/chart/plan_worst_case_marker_layer.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_worst_case_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/planner_results.dart';
import '../../../helpers/test_app.dart';

const _marker = Key('planChartWorstCaseMarker');

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool longer = false,
    GasMix bailout = const GasMix(o2: 21),
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...plannerResultsInline(),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
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
    container.read(divePlanNotifierProvider.notifier)
      ..addSimplePlan(maxDepth: 40, bottomTimeMinutes: 25)
      ..updateMode(domain.PlanMode.ccr)
      ..addTank(
        DiveTank(
          id: 'bo',
          volume: 11.1,
          startPressure: 200,
          gasMix: bailout,
          role: TankRole.bailout,
        ),
      );
    await tester.pumpAndSettle();
    final selection = container.read(contingencySelectionProvider.notifier);
    longer ? selection.toggleLonger() : selection.toggleDeeper();
    await tester.pumpAndSettle();
    return container;
  }

  /// The depth the marker's diamond sits at, read back from its pixel: the
  /// chart's depth axis spans the deepest drawn line, padded by a tenth.
  double markerDepth(WidgetTester tester, double deepestDrawn) {
    final placed =
        (tester.widget<CustomPaint>(find.byKey(_marker)).painter
                as PlanWorstCaseMarkerPainter)
            .placed;
    return (placed.anchor.dy - placed.plot.top) /
        placed.plot.height *
        deepestDrawn *
        1.1;
  }

  testWidgets('+5 m marks the worst case on the deeper line in plan view', (
    tester,
  ) async {
    await mount(tester);

    expect(markerDepth(tester, 45), closeTo(45, 0.5));
  });

  testWidgets('+5 m marks the worst case on the deeper line in Bailout view', (
    tester,
  ) async {
    final container = await mount(tester);
    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
    await tester.pumpAndSettle();

    expect(markerDepth(tester, 45), closeTo(45, 0.5));
  });

  testWidgets(
    '+5 min marks the worst case at the end of the longer bottom, not on the '
    "plan's bailout at that time",
    (tester) async {
      final container = await mount(tester, longer: true);
      container.read(chartDisplayModeProvider.notifier).state =
          ChartDisplayMode.bailout;
      await tester.pumpAndSettle();

      expect(markerDepth(tester, 40), closeTo(40, 0.5));
    },
  );

  testWidgets(
    '+5 min flags the bailout gas where the longer dive switches to it',
    (tester) async {
      final container = await mount(
        tester,
        longer: true,
        bailout: const GasMix(o2: 28),
      );
      container.read(chartDisplayModeProvider.notifier).state =
          ChartDisplayMode.bailout;
      await tester.pumpAndSettle();

      final worstCase = container.read(planChartWorstCaseProvider)!;
      final flags =
          (tester
                      .widget<CustomPaint>(
                        find.byKey(const Key('planChartSeries')),
                      )
                      .painter
                  as PlanChartSeriesPainter)
              .flaggedGasSwitches;
      expect(flags, isNotEmpty);
      expect(
        flags.first.timeSeconds,
        greaterThanOrEqualTo(worstCase.runtimeSeconds),
      );
    },
  );
}
