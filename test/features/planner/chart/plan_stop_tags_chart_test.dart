import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/planner_results.dart';
import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a chart without stop tags draws none', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...plannerResultsInline(),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SizedBox(
          width: 600,
          height: 400,
          child: PlanProfileChart(showStopTags: false),
        ),
      ),
    );
    ProviderScope.containerOf(tester.element(find.byType(PlanProfileChart)))
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                .painter
            as PlanChartSeriesPainter;
    expect(painter.series.stopLabels, isNotEmpty);
    expect(painter.stopTags, isEmpty);
  });

  testWidgets('the Bailout view keeps its own tags under a preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...plannerResultsInline(),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SizedBox(
          width: 600,
          height: 400,
          child: PlanProfileChart(),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    // 30 m, so the 32% bailout covers the whole dive and there is a picture.
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
    await tester.pumpAndSettle();
    container.read(chartDisplayModeProvider.notifier).state =
        ChartDisplayMode.bailout;
    await tester.pumpAndSettle();
    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    await tester.pumpAndSettle();
    expect(container.read(planChartBailoutProvider).picture, isNotNull);

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                .painter
            as PlanChartSeriesPainter;
    // The ghost is the live CCR plan's contingency, not a variant of the
    // bailout picture, so the bailout stops keep their own plain tags.
    (double, double, int) stop(CanvasMarker m) =>
        (m.timeSeconds, m.depth, m.durationSeconds);
    final bailout = container.read(planCanvasSeriesProvider);
    final ghost = container.read(contingencyGhostSeriesProvider)!;
    expect(
      painter.stopTags.map((t) => stop(t.marker)),
      orderedEquals(bailout.stopLabels.map(stop)),
    );
    expect(
      bailout.stopLabels.map(stop),
      isNot(orderedEquals(ghost.stopLabels.map(stop))),
    );
    expect(painter.stopTags.every((t) => t.change == null && !t.isNew), isTrue);
  });

  testWidgets('a previewed contingency moves the stop tags onto its profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...plannerResultsInline(),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SizedBox(
          width: 600,
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
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    PlanChartSeriesPainter painter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                .painter
            as PlanChartSeriesPainter;

    final base = container.read(planCanvasSeriesProvider);
    expect(
      painter().stopTags.map((t) => t.marker),
      orderedEquals(base.stopLabels),
    );
    expect(painter().stopTags.every((t) => t.change == null), isTrue);

    container.read(contingencySelectionProvider.notifier).toggleDeeper();
    container.read(contingencySelectionProvider.notifier).toggleLonger();
    await tester.pumpAndSettle();

    final ghost = container.read(contingencyGhostSeriesProvider)!;
    expect(
      painter().stopTags.map((t) => t.marker),
      orderedEquals(ghost.stopLabels),
    );
    // Five metres deeper and five minutes longer lengthens the stops.
    expect(painter().stopTags.any((t) => t.change != null || t.isNew), isTrue);
  });
}
