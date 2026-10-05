import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> weekly(int n, {DateTime? from}) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: (from ?? DateTime.utc(2022, 1, 3)).add(Duration(days: i * 7)),
    value: 10.0 + i % 7,
    diveId: 'd$i',
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

LineChartData data(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

double ms(DateTime d) => d.millisecondsSinceEpoch.toDouble();

void main() {
  const year1 = TrendRange.preset(TrendRangePreset.year1);
  const day = 86400000.0;

  testWidgets('a preset shows the last year of a four-year series', (
    tester,
  ) async {
    final points = weekly(209);
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: year1)));
    final last = points.last.date;
    expect(data(tester).maxX, closeTo(ms(last), 1000));
    expect(
      data(tester).minX,
      closeTo(ms(DateTime.utc(last.year - 1, last.month, last.day)), 1000),
    );
  });

  testWidgets('three months of ten years is not capped at a tenth', (
    tester,
  ) async {
    final points = weekly(522);
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: points,
          range: const TrendRange.preset(TrendRangePreset.months3),
        ),
      ),
    );
    final span = data(tester).maxX - data(tester).minX;
    expect(span, lessThan(100 * day));
    expect(span, greaterThan(85 * day));
  });

  testWidgets('a new range prop moves the window', (tester) async {
    final points = weekly(209);
    await tester.pumpWidget(host(DiveTrendChart(points: points)));
    final allMin = data(tester).minX;
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: year1)));
    expect(data(tester).minX, greaterThan(allMin));
  });

  testWidgets('a mouse drag reports the new window as a custom range', (
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
    final centre = tester.getCenter(find.byType(LineChart));
    final gesture = await tester.startGesture(
      centre,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(120, 0));
    await gesture.up();
    await tester.pump();

    expect(reported?.preset, TrendRangePreset.custom);
    expect(ms(reported!.start!), closeTo(data(tester).minX, 1000));
    expect(ms(reported!.end!), closeTo(data(tester).maxX, 1000));
  });

  testWidgets('reset zoom reports All', (tester) async {
    TrendRange? reported;
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          chartId: 'c',
          points: weekly(209),
          range: year1,
          onRangeChanged: (r) => reported = r,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('trend-c-zoom-reset')));
    await tester.pump();
    expect(reported, TrendRange.all);
  });

  testWidgets('a custom range keeps its dates when the data shrinks', (
    tester,
  ) async {
    final range = TrendRange.custom(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2024, 7, 1),
    );
    final points = weekly(209);
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: range)));
    expect(data(tester).minX, closeTo(ms(DateTime.utc(2024)), day));

    final narrowed = points
        .where((p) => !p.date.isBefore(DateTime.utc(2023, 6, 1)))
        .toList();
    await tester.pumpWidget(
      host(DiveTrendChart(points: narrowed, range: range)),
    );
    expect(data(tester).minX, closeTo(ms(DateTime.utc(2024)), day));
    expect(data(tester).maxX, closeTo(ms(DateTime.utc(2024, 7)), day));
  });

  testWidgets('a single-day series with a preset still draws', (tester) async {
    final points = [
      for (var i = 0; i < 3; i++)
        TrendDataPoint(date: DateTime.utc(2025, 5, 1), value: 10.0 + i),
    ];
    await tester.pumpWidget(host(DiveTrendChart(points: points, range: year1)));
    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
