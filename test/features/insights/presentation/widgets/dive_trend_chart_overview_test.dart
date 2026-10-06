import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> weekly(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2022, 1, 3).add(Duration(days: i * 7)),
    value: 10.0 + i % 7,
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Offset stripAt(WidgetTester tester, double fraction) {
  final rect = tester.getRect(find.byType(ChartOverviewStrip));
  return Offset(rect.left + rect.width * fraction, rect.center.dy);
}

void main() {
  const year1 = TrendRange.preset(TrendRangePreset.year1);

  testWidgets('the strip appears only once the chart is zoomed', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(DiveTrendChart(chartId: 'c', points: weekly(52))),
    );
    expect(find.byType(ChartOverviewStrip), findsNothing);
    await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
    await tester.pump();
    expect(find.byType(ChartOverviewStrip), findsOneWidget);
  });

  testWidgets('dragging the strip pans the chart and reports at the end', (
    tester,
  ) async {
    TrendRange? reported;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: weekly(209),
          range: year1,
          onRangeChanged: (r) => reported = r,
        ),
      ),
    );
    final before = tester.widget<LineChart>(find.byType(LineChart)).data.minX;
    await tester.dragFrom(stripAt(tester, 0.875), const Offset(-60, 0));
    await tester.pump();
    final after = tester.widget<LineChart>(find.byType(LineChart)).data.minX;
    expect(after, lessThan(before));
    expect(reported?.preset, TrendRangePreset.custom);
  });

  testWidgets('widening the window to everything reports All and hides it', (
    tester,
  ) async {
    TrendRange? reported;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: weekly(209),
          range: year1,
          onRangeChanged: (r) => reported = r,
        ),
      ),
    );
    final rect = tester.getRect(find.byType(ChartOverviewStrip));
    // The year window starts about three quarters of the way along; drag
    // its left edge past the strip's start.
    final edge = Offset(
      rect.left +
          rect.width *
              (1 -
                  365 /
                      DateTime.utc(2022, 1, 3)
                          .add(const Duration(days: 208 * 7))
                          .difference(DateTime.utc(2022, 1, 3))
                          .inDays),
      rect.center.dy,
    );
    await tester.dragFrom(edge, Offset(-rect.width, 0));
    await tester.pump();
    expect(reported, TrendRange.all);
    expect(find.byType(ChartOverviewStrip), findsNothing);
  });

  testWidgets('the strip starts where the plot starts, axis label or not', (
    tester,
  ) async {
    for (final label in [null, 'L/min']) {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            key: ValueKey(label),
            chartId: 'c',
            points: weekly(52),
            yAxisLabel: label,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
      await tester.pump();
      final chartLeft = tester.getTopLeft(find.byType(LineChart)).dx;
      final stripLeft = tester.getTopLeft(find.byType(ChartOverviewStrip)).dx;
      // 50 px of tick labels, plus 20 px for the rotated axis name.
      expect(stripLeft - chartLeft, label == null ? 50 : 70);
    }
  });
}
