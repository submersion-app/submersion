import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/category_bar_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_axis.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The y-axis scale that lets Time at depth tick in hours (issue #4600).
Future<void> _pump(WidgetTester tester, Widget chart) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 400, child: chart)),
  ),
);

void main() {
  test('a scale below one is rejected', () {
    expect(
      () => CategoryBarChart(data: const [], yAxisScale: 0),
      throwsAssertionError,
    );
  });

  testWidgets('default scale keeps whole-count ticks', (tester) async {
    await _pump(
      tester,
      const CategoryBarChart(
        data: [(label: 'a', count: 10), (label: 'b', count: 6)],
      ),
    );

    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    final expected = ChartAxis.forCounts(10);
    expect(data.gridData.horizontalInterval, expected.interval);
    expect(data.maxY, expected.max);
  });

  testWidgets('scale 60 ticks in whole hours over minute values', (
    tester,
  ) async {
    await _pump(
      tester,
      const CategoryBarChart(
        data: [(label: 'a', count: 66240)],
        yAxisScale: 60,
      ),
    );

    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    final hourAxis = ChartAxis.forCounts(66240 / 60);
    expect(data.gridData.horizontalInterval, hourAxis.interval * 60);
    expect(
      data.titlesData.leftTitles.sideTitles.interval,
      hourAxis.interval * 60,
    );
    expect(data.maxY, hourAxis.max * 60);
    expect(data.maxY, greaterThanOrEqualTo(66240));
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('60000'), findsNothing);
  });
}
