import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/shared/widgets/defer_until_painted.dart';

void main() {
  Future<void> pumpGrid(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              DashboardGrid(
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
            ],
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
            body: CustomScrollView(
              slivers: [
                DashboardGrid(
                  entries: [
                    PairBlock(
                      first: SizedBox(key: Key('media'), height: 220),
                      second: SizedBox(key: Key('sites'), height: 260),
                    ),
                    ThirdBlock(SizedBox(key: Key('t1'), height: 40)),
                    ThirdBlock(SizedBox(key: Key('t2'), height: 40)),
                  ],
                ),
              ],
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

  group('lazy rows', () {
    /// One screen of rows, then [rest], in a phone-sized 600px page.
    Widget page(List<DashboardEntry> rest, {ScrollController? controller}) {
      return MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              DashboardGrid(
                entries: [
                  const FullBlock(SizedBox(key: Key('top'), height: 600)),
                  ...rest,
                ],
              ),
            ],
          ),
        ),
      );
    }

    setUp(() => _buildCounts.clear());

    testWidgets('a row beyond the cache band is not built until approached', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        page(const [
          FullBlock(SizedBox(key: Key('spacer'), height: 600)),
          FullBlock(_CountsBuilds('far')),
        ], controller: scroll),
      );

      expect(_buildCounts['far'], isNull);

      // Still off screen, but within the sliver's cache extent of it.
      scroll.jumpTo(500);
      await tester.pump();

      expect(_buildCounts['far'], 1);
    });

    testWidgets('a row stays built after it scrolls away', (tester) async {
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        page(const [
          FullBlock(_CountsBuilds('first')),
          FullBlock(SizedBox(key: Key('spacer'), height: 3000)),
        ], controller: scroll),
      );
      final state = tester.state(
        find.byType(_CountsBuilds, skipOffstage: false),
      );

      scroll.jumpTo(2500);
      await tester.pump();
      scroll.jumpTo(0);
      await tester.pump();

      // Same state, same build: a map keeps its tiles and a ribbon its offset
      // rather than starting over each time the page scrolls past.
      expect(
        tester.state(find.byType(_CountsBuilds, skipOffstage: false)),
        same(state),
      );
      expect(_buildCounts['first'], 1);
    });

    testWidgets('the gap above a row does not put the row on screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The gap under the 595px row reaches the fold; the next card does not
      // start until 607, so it must not paint.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                DashboardGrid(
                  entries: [
                    FullBlock(SizedBox(key: Key('top'), height: 595)),
                    FullBlock(
                      DeferUntilPainted(
                        placeholder: SizedBox(key: Key('wait'), height: 40),
                        child: SizedBox(key: Key('shown'), height: 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('shown'), skipOffstage: false), findsNothing);
      expect(
        find.byKey(const Key('wait'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('a card arriving above keeps the rows below it mounted', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(page(const [FullBlock(_CountsBuilds('map'))]));
      final state = tester.state(find.byType(_CountsBuilds));

      // Cards resolve one provider at a time, so this happens at every launch.
      await tester.pumpWidget(
        page(const [
          ThirdBlock(SizedBox(key: Key('late'), height: 40)),
          FullBlock(_CountsBuilds('map')),
        ]),
      );

      expect(find.byKey(const Key('late')), findsOneWidget);
      expect(tester.state(find.byType(_CountsBuilds)), same(state));
    });
  });
}

/// Builds per label across the running test.
final _buildCounts = <String, int>{};

class _CountsBuilds extends StatefulWidget {
  final String label;
  const _CountsBuilds(this.label);

  @override
  State<_CountsBuilds> createState() => _CountsBuildsState();
}

class _CountsBuildsState extends State<_CountsBuilds> {
  @override
  Widget build(BuildContext context) {
    _buildCounts.update(widget.label, (n) => n + 1, ifAbsent: () => 1);
    return const SizedBox(height: 40);
  }
}
