import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/planner_results.dart';
import '../../../helpers/test_app.dart';

const _ean50 = DiveTank(
  id: 'ean50',
  volume: 7,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    int bottomMinutes = 25,
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
      ..addSimplePlan(maxDepth: 40, bottomTimeMinutes: bottomMinutes)
      ..addTank(_ean50);
    await tester.pumpAndSettle();
    return container;
  }

  List<CanvasMarker> flags(WidgetTester tester) =>
      (tester
                  .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                  .painter
              as PlanChartSeriesPainter)
          .flaggedGasSwitches;

  List<String> flagLabels(WidgetTester tester) => [
    for (final marker
        in (tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('planChartSeries')),
                    )
                    .painter
                as PlanChartSeriesPainter)
            .flaggedGasSwitches)
      marker.label,
  ];

  testWidgets('the plan flags its switch to the deco gas', (tester) async {
    await mount(tester);

    expect(flagLabels(tester), contains('EAN50'));
  });

  testWidgets('a preview without the deco gas flags no switch to it', (
    tester,
  ) async {
    final container = await mount(tester);
    container
        .read(contingencySelectionProvider.notifier)
        .toggleLostGas(_ean50.id);
    await tester.pumpAndSettle();

    expect(container.read(contingencyGhostSeriesProvider), isNotNull);
    expect(flagLabels(tester), isNot(contains('EAN50')));
  });

  testWidgets('+5 min flags the deco gas where the longer dive switches', (
    tester,
  ) async {
    final container = await mount(tester, bottomMinutes: 45);
    final planSwitch = flags(tester).single.timeSeconds;

    container.read(contingencySelectionProvider.notifier).toggleLonger();
    await tester.pumpAndSettle();

    expect(flags(tester).single.label, 'EAN50');
    expect(flags(tester).single.timeSeconds, greaterThan(planSwitch + 4 * 60));
  });
}
