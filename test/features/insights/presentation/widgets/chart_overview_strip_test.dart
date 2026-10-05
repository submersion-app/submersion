import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late ChartViewport latest;
  late int ends;

  Future<void> pump(WidgetTester tester, ChartViewport initial) async {
    latest = initial;
    ends = 0;
    var vp = initial;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: StatefulBuilder(
                builder: (context, setState) => ChartOverviewStrip(
                  points: const [Offset(0, 0), Offset(0.5, 0.5), Offset(1, 1)],
                  viewport: vp,
                  onViewportChanged: (next) {
                    latest = next;
                    setState(() => vp = next);
                  },
                  onChangeEnd: () => ends++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset at(WidgetTester tester, double fraction) {
    final rect = tester.getRect(
      find.byKey(const ValueKey('trend-overview-strip')),
    );
    return Offset(rect.left + rect.width * fraction, rect.center.dy);
  }

  testWidgets('dragging inside the window moves it', (tester) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.dragFrom(at(tester, 0.375), const Offset(40, 0));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.35, 0.01));
    expect(latest.windowEnd - latest.windowStart, closeTo(0.25, 1e-6));
    expect(ends, 1);
  });

  testWidgets('dragging the left edge resizes and holds the right edge', (
    tester,
  ) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.dragFrom(at(tester, 0.25), const Offset(-40, 0));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.15, 0.01));
    expect(latest.windowEnd, closeTo(0.5, 0.01));
  });

  testWidgets('dragging the right edge resizes and holds the left edge', (
    tester,
  ) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.dragFrom(at(tester, 0.5), const Offset(40, 0));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.25, 0.01));
    expect(latest.windowEnd, closeTo(0.6, 0.01));
  });

  testWidgets('tapping outside the window centres it there', (tester) async {
    await pump(tester, ChartViewport.forWindow(0.25, 0.5));
    await tester.tapAt(at(tester, 0.9));
    await tester.pump();
    expect(latest.windowEnd, closeTo(1.0, 1e-6));
    expect(latest.windowStart, closeTo(0.75, 1e-6));
    expect(ends, 1);
  });

  testWidgets('tapping inside the window leaves it alone', (tester) async {
    final initial = ChartViewport.forWindow(0.25, 0.5);
    await pump(tester, initial);
    await tester.tapAt(at(tester, 0.4));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.25, 1e-6));
  });

  testWidgets('a narrow window drags as a move, not a resize', (tester) async {
    // 2% of a 400 px strip is 8 px: every point inside it is within the
    // 10 px edge slop, which used to turn every drag into a resize.
    await pump(tester, ChartViewport.forWindow(0.5, 0.52, zoomLimit: 100));
    await tester.dragFrom(at(tester, 0.51), const Offset(40, 0));
    await tester.pump();
    expect(latest.windowStart, closeTo(0.6, 0.01));
    expect(latest.windowEnd - latest.windowStart, closeTo(0.02, 1e-6));
  });
}
