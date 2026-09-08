import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';

void main() {
  Future<void> pumpGrid(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardGrid(
              entries: [
                FullBlock(SizedBox(key: Key('hero'), height: 40)),
                LeadSideGroup(
                  lead: SizedBox(key: Key('lead'), height: 120),
                  side: [
                    SizedBox(key: Key('side1'), height: 40),
                    SizedBox(key: Key('side2'), height: 40),
                  ],
                ),
                ThirdBlock(SizedBox(key: Key('t1'), height: 40)),
                ThirdBlock(SizedBox(key: Key('t2'), height: 40)),
                ThirdBlock(SizedBox(key: Key('t3'), height: 40)),
                FullBlock(SizedBox(key: Key('map'), height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('phone (<800) stacks all blocks in order', (tester) async {
    await pumpGrid(tester, 500);
    final keys = ['hero', 'lead', 'side1', 'side2', 't1', 't2', 't3', 'map'];
    double lastBottom = -1;
    for (final k in keys) {
      final rect = tester.getRect(find.byKey(Key(k)));
      // Each block starts at or below the previous block's BOTTOM, so a
      // vertical overlap would fail this (tracking .top would not).
      expect(
        rect.top,
        greaterThanOrEqualTo(lastBottom - 0.01),
        reason: '$k should not overlap the previous block',
      );
      lastBottom = rect.bottom;
      expect(rect.width, 500);
    }
  });

  testWidgets('3 columns (>=1200): thirds share one row, lead spans 2/3', (
    tester,
  ) async {
    await pumpGrid(tester, 1300);
    final t1 = tester.getRect(find.byKey(const Key('t1')));
    final t2 = tester.getRect(find.byKey(const Key('t2')));
    final t3 = tester.getRect(find.byKey(const Key('t3')));
    expect(t1.top, t2.top);
    expect(t2.top, t3.top);
    final lead = tester.getRect(find.byKey(const Key('lead')));
    final side1 = tester.getRect(find.byKey(const Key('side1')));
    expect(side1.top, lead.top);
    expect(lead.width, greaterThan(side1.width * 1.8));
    // Side widgets stack below one another with natural heights.
    final side2 = tester.getRect(find.byKey(const Key('side2')));
    expect(side2.top, greaterThan(side1.bottom - 0.01));
  });

  testWidgets('2 columns (800-1199): thirds flow 2-up, leftover shares row', (
    tester,
  ) async {
    await pumpGrid(tester, 1000);
    final t1 = tester.getRect(find.byKey(const Key('t1')));
    final t2 = tester.getRect(find.byKey(const Key('t2')));
    final t3 = tester.getRect(find.byKey(const Key('t3')));
    expect(t1.top, t2.top);
    expect(t3.top, greaterThan(t1.bottom - 0.01));
    expect(t3.width, 1000);
    final lead = tester.getRect(find.byKey(const Key('lead')));
    final side1 = tester.getRect(find.byKey(const Key('side1')));
    expect(lead.width, closeTo(side1.width, 1.0));
  });

  group('PairBlock', () {
    Future<void> pumpPair(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardGrid(
                entries: [
                  PairBlock(
                    first: SizedBox(key: Key('media'), height: 220),
                    second: SizedBox(key: Key('sites'), height: 260),
                  ),
                  ThirdBlock(SizedBox(key: Key('t1'), height: 40)),
                  ThirdBlock(SizedBox(key: Key('t2'), height: 40)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('phone (<800) stacks the pair in order', (tester) async {
      await pumpPair(tester, 500);
      final media = tester.getRect(find.byKey(const Key('media')));
      final sites = tester.getRect(find.byKey(const Key('sites')));
      expect(sites.top, greaterThanOrEqualTo(media.bottom - 0.01));
      expect(media.width, 500);
      expect(sites.width, 500);
    });

    testWidgets('2 columns (800-1199) splits the row 50/50', (tester) async {
      await pumpPair(tester, 1000);
      final media = tester.getRect(find.byKey(const Key('media')));
      final sites = tester.getRect(find.byKey(const Key('sites')));
      expect(media.top, sites.top);
      expect(media.width, closeTo(sites.width, 1.0));
    });

    testWidgets('3 columns (>=1200) still splits 50/50, not 1/3', (
      tester,
    ) async {
      await pumpPair(tester, 1300);
      final media = tester.getRect(find.byKey(const Key('media')));
      final sites = tester.getRect(find.byKey(const Key('sites')));
      expect(media.top, sites.top);
      expect(media.width, closeTo(sites.width, 1.0));
      // Half the row, not the third a ThirdBlock would take at 3 columns.
      expect(media.width, greaterThan(1300 / 3));
    });

    testWidgets('following thirds do not join the pair row', (tester) async {
      await pumpPair(tester, 1300);
      final media = tester.getRect(find.byKey(const Key('media')));
      final t1 = tester.getRect(find.byKey(const Key('t1')));
      final t2 = tester.getRect(find.byKey(const Key('t2')));
      expect(t1.top, greaterThan(media.bottom - 0.01));
      expect(t1.top, t2.top);
    });

    testWidgets('the taller card does not stretch its partner', (tester) async {
      await pumpPair(tester, 1300);
      final media = tester.getRect(find.byKey(const Key('media')));
      final sites = tester.getRect(find.byKey(const Key('sites')));
      // Top-aligned natural heights: no IntrinsicHeight in the grid.
      expect(media.height, 220);
      expect(sites.height, 260);
    });
  });
}
