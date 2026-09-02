import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
    value: 10.0 + i,
  ),
);

Widget host(AsyncValue<List<TrendDataPoint>> value) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrendChartSection(
            chartId: TrendChartIds.depth,
            title: 'Maximum Depth Progression',
            subtitle: 'Depth per dive in range',
            pointsAsync: value,
            errorMessage: 'Failed to load depth progression',
            lineColor: Colors.indigo,
            valueFormatter: (v) => '${v.toStringAsFixed(1)}m',
            rateFormatter: (v) => '${v.toStringAsFixed(1)}m',
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the title, the chart and the control strip', (
    tester,
  ) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    expect(find.text('Maximum Depth Progression'), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsOneWidget);
    expect(find.byType(TrendControlStrip), findsOneWidget);
  });

  testWidgets('starts in per-dive mode with the rolling mean on', (
    tester,
  ) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    expect(find.text('Every dive'), findsOneWidget);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.none);
    expect(chart.showRollingMean, isTrue);
    expect(chart.showLinearFit, isFalse);
  });

  testWidgets('choosing monthly re-renders the chart aggregated', (
    tester,
  ) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('trend-aggregation-${TrendChartIds.depth}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly average').last);
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.monthly);
  });

  testWidgets('tapping the rate legend turns the linear fit on', (
    tester,
  ) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('trend-legend-rate-${TrendChartIds.depth}')),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.showLinearFit, isTrue);
  });

  testWidgets('shows the fitted rate once the fit is on', (tester) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('trend-legend-rate-${TrendChartIds.depth}')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('/yr'), findsOneWidget);
  });

  testWidgets('shows the error message on failure', (tester) async {
    await tester.pumpWidget(
      host(const AsyncValue.error('boom', StackTrace.empty)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load depth progression'), findsOneWidget);
  });

  testWidgets('hides the control strip while loading', (tester) async {
    await tester.pumpWidget(host(const AsyncValue.loading()));
    await tester.pump();

    expect(find.byType(TrendControlStrip), findsNothing);
  });

  testWidgets('the rolling mean is drawn in a different colour to the data', (
    tester,
  ) async {
    // Same colour for both makes the smoother indistinguishable from the
    // series it smooths, and the legend swatch stops identifying anything.
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));

    expect(chart.rollingColor, isNotNull);
    expect(chart.rollingColor, isNot(chart.pointColor));
    expect(chart.rateColor, isNot(chart.pointColor));
    expect(chart.rateColor, isNot(chart.rollingColor));
  });
}
