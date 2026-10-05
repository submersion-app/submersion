import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
  n,
  (i) => TrendDataPoint(
    date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
    value: 10.0 + i % 5,
  ),
);

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

double minX(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.minX;

Future<void> zoomIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('trend-c-zoom-in')));
  await tester.pump();
}

void main() {
  Widget chart() => host(DiveTrendChart(chartId: 'c', points: series(60)));

  testWidgets('a horizontal wheel pans a zoomed chart', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final centre = tester.getCenter(find.byType(LineChart));
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(const Offset(120, 0)));
    await tester.pump();

    expect(minX(tester), greaterThan(before));
  });

  testWidgets('shift+wheel pans instead of zooming', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);
    final beforeSpan =
        tester.widget<LineChart>(find.byType(LineChart)).data.maxX - before;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final centre = tester.getCenter(find.byType(LineChart));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.minX, greaterThan(before));
    expect(data.maxX - data.minX, closeTo(beforeSpan, 1));
  });

  testWidgets('a trackpad sideways swipe pans', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);

    final pointer = TestPointer(2, PointerDeviceKind.trackpad);
    final centre = tester.getCenter(find.byType(LineChart));
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(centre, pan: const Offset(-80, 0)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(minX(tester), greaterThan(before));
  });

  testWidgets('arrow keys pan once the chart has focus', (tester) async {
    await tester.pumpWidget(chart());
    await zoomIn(tester);
    final before = minX(tester);

    await tester.tap(find.byType(LineChart), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final afterRight = minX(tester);
    expect(afterRight, greaterThan(before));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(minX(tester), lessThan(afterRight));
  });

  testWidgets('arrow keys do nothing on an unzoomed chart', (tester) async {
    await tester.pumpWidget(chart());
    final before = minX(tester);
    await tester.tap(find.byType(LineChart), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(minX(tester), before);
  });
}
