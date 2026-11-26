import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_stop_list.dart';

/// Tags in time order, deepest first, as the chart has them.
List<PlanStopTag> _tags(List<(double depth, int minutes)> stops) {
  var t = 1800.0;
  return [
    for (final (depth, minutes) in stops)
      PlanStopTag(
        marker: CanvasMarker(
          t += 120,
          depth,
          '',
          durationSeconds: minutes * 60,
        ),
        label: '',
      ),
  ];
}

String _metres(double m) => '${m.round()}m';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.topRight, child: child),
  ),
);

void main() {
  testWidgets('the shallowest stop is on top', (tester) async {
    await tester.pumpWidget(
      _host(
        PlanStopList(
          tags: _tags([(9, 2), (6, 1), (3, 3)]),
          formatDepth: _metres,
        ),
      ),
    );

    final top = tester.getTopLeft(find.text('3m')).dy;
    final middle = tester.getTopLeft(find.text('6m')).dy;
    final bottom = tester.getTopLeft(find.text('9m')).dy;
    expect(top, lessThan(middle));
    expect(middle, lessThan(bottom));
    expect(find.text('3′'), findsOneWidget);
  });

  testWidgets('a changed stop shows its change, a new one the warning colour', (
    tester,
  ) async {
    final tags = [
      const PlanStopTag(
        marker: CanvasMarker(2000, 12, '', durationSeconds: 120),
        label: '',
        isNew: true,
      ),
      const PlanStopTag(
        marker: CanvasMarker(2200, 6, '', durationSeconds: 300),
        label: '',
        change: '+3',
      ),
    ];
    await tester.pumpWidget(
      _host(PlanStopList(tags: tags, formatDepth: _metres)),
    );

    expect(find.text('+3'), findsOneWidget);
    final palette = PlanChartPalette.of(
      Theme.of(tester.element(find.byType(PlanStopList))),
    );
    expect(
      tester.widget<Text>(find.text('12m')).style?.color,
      palette.stopTagChangeText,
    );
    expect(
      tester.widget<Text>(find.text('6m')).style?.color,
      isNot(palette.stopTagChangeText),
    );
    // On a phone the change is plain warning-coloured text, no pill.
    expect(
      tester.widget<Text>(find.text('+3')).style?.color,
      palette.stopTagChangeText,
    );
    expect(
      find.ancestor(
        of: find.text('+3'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color != null,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('no stops, no list', (tester) async {
    await tester.pumpWidget(
      _host(const PlanStopList(tags: [], formatDepth: _metres)),
    );

    expect(tester.getSize(find.byType(PlanStopList)), Size.zero);
  });

  testWidgets('up to six stops fit without scrolling', (tester) async {
    await tester.pumpWidget(
      _host(
        PlanStopList(
          tags: _tags([(18, 1), (15, 1), (12, 2), (9, 3), (6, 4), (3, 9)]),
          formatDepth: _metres,
        ),
      ),
    );

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, 0);
  });

  testWidgets('more than six stops scroll, opening at the shallow end', (
    tester,
  ) async {
    final stops = [
      for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1),
    ]; // 14 stops
    await tester.pumpWidget(
      _host(PlanStopList(tags: _tags(stops), formatDepth: _metres)),
    );

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, greaterThan(0));
    final rowHeight =
        tester.getTopLeft(find.text('6m')).dy -
        tester.getTopLeft(find.text('3m')).dy;
    expect(
      tester.getSize(find.byType(PlanStopList)).height,
      // Six rows, plus the divider above them.
      closeTo(rowHeight * 6, 5),
    );

    await tester.drag(find.byType(PlanStopList), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(position.pixels, position.maxScrollExtent);
  });

  testWidgets('a swipe past the end of the list scrolls the page', (
    tester,
  ) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: page,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: PlanStopList(tags: _tags(stops), formatDepth: _metres),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );

    // A short swipe moves only the list; one past its end moves the page.
    await tester.drag(find.byType(PlanStopList), const Offset(0, -60));
    await tester.pumpAndSettle();
    final list = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(PlanStopList),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(list.pixels, greaterThan(0));
    expect(page.offset, 0);
    await tester.drag(find.byType(PlanStopList), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(list.pixels, list.maxScrollExtent);
    expect(page.offset, greaterThan(0));
  });

  Future<int> pressesUnder(WidgetTester tester, int stopCount) async {
    var presses = 0;
    final stops = [
      for (var i = 0; i < stopCount; i++) ((3.0 * (stopCount - i)), 1),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => presses++,
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: PlanStopList(tags: _tags(stops), formatDepth: _metres),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('3m'), warnIfMissed: false);
    return presses;
  }

  testWidgets('a list that fits lets presses through to the chart', (
    tester,
  ) async {
    expect(await pressesUnder(tester, 3), 1);
  });

  testWidgets('a list that scrolls keeps presses for itself', (tester) async {
    expect(await pressesUnder(tester, 14), 0);
  });

  testWidgets('a swipe past the end never moves a horizontal parent', (
    tester,
  ) async {
    final pages = PageController();
    addTearDown(pages.dispose);
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: PageView(
          controller: pages,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: PlanStopList(tags: _tags(stops), formatDepth: _metres),
            ),
            const SizedBox(),
          ],
        ),
      ),
    );

    await tester.drag(find.byType(PlanStopList), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(pages.offset, 0);
  });

  testWidgets('the list shrinks to the room it is given', (tester) async {
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    await tester.pumpWidget(
      _host(
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 40),
          child: PlanStopList(tags: _tags(stops), formatDepth: _metres),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PlanStopList)).height, 40);
  });

  testWidgets('a reserve below the list costs rows, never all but none', (
    tester,
  ) async {
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    Future<double> heightWith(double maxHeight) async {
      await tester.pumpWidget(
        _host(
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: PlanStopList(
              tags: _tags(stops),
              formatDepth: _metres,
              bottomReserve: 48,
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(PlanStopList)).height;
    }

    expect(await heightWith(100), 100 - 48);
    // Less than one row left: nothing rather than a sliver.
    expect(await heightWith(60), 0);
  });

  Future<void> pumpIn(
    WidgetTester tester,
    TextDirection direction,
    List<PlanStopTag> tags,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: PlanStopList(tags: tags, formatDepth: _metres),
          ),
        ),
      ),
    ),
  );

  testWidgets('depth and minutes keep their gap left to right', (tester) async {
    await pumpIn(tester, TextDirection.ltr, _tags([(21, 3)]));

    expect(
      tester.getTopLeft(find.text('3′')).dx -
          tester.getTopRight(find.text('21m')).dx,
      greaterThanOrEqualTo(6),
    );
  });

  testWidgets('right to left, the columns keep their gaps and the scrollbar '
      'its room on the left', (tester) async {
    final changed = [
      const PlanStopTag(
        marker: CanvasMarker(2000, 21, '', durationSeconds: 180),
        label: '',
        change: '+2',
      ),
      for (final tag in _tags([
        for (var d = 18; d >= 3; d -= 3) (d.toDouble(), 1),
      ]))
        tag,
    ];
    await pumpIn(tester, TextDirection.rtl, changed);

    // Depth on the right, then minutes, then the change, each apart.
    expect(
      tester.getTopLeft(find.text('21m')).dx -
          tester.getTopRight(find.text('3′')).dx,
      greaterThanOrEqualTo(6),
    );
    expect(
      tester.getTopLeft(find.text('3′')).dx -
          tester.getTopRight(find.text('+2')).dx,
      greaterThanOrEqualTo(5),
    );
    // The sign stays in front of the number, +2 and not 2+.
    expect(
      tester.widget<Text>(find.text('+2')).textDirection,
      TextDirection.ltr,
    );
    // The scrollbar draws on the left, so the room for it is there.
    final list = tester.getRect(find.byType(PlanStopList));
    final table = tester.getRect(find.byType(Table));
    expect(table.left - list.left, 6);
    expect(table.right, list.right);
  });

  testWidgets('the gap above the list goes with it', (tester) async {
    final stops = _tags([for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)]);
    Future<double> heightWith(double maxHeight, {double gap = 0}) async {
      await tester.pumpWidget(
        _host(
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: PlanStopList(tags: stops, formatDepth: _metres, topGap: gap),
          ),
        ),
      );
      return tester.getSize(find.byType(PlanStopList)).height;
    }

    expect(await heightWith(200, gap: 3), await heightWith(200) + 3);
    // Not even a row fits: no list, and no gap left behind.
    expect(await heightWith(24, gap: 3), 0);
  });

  testWidgets('a flick past the end carries the page on after the finger '
      'lifts', (tester) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: page,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: PlanStopList(tags: _tags(stops), formatDepth: _metres),
              ),
              const SizedBox(height: 4000),
            ],
          ),
        ),
      ),
    );

    await tester.fling(find.byType(PlanStopList), const Offset(0, -300), 3000);
    await tester.pump();
    final atRelease = page.offset;
    expect(atRelease, greaterThan(0));
    await tester.pumpAndSettle();
    expect(page.offset, greaterThan(atRelease));
  });

  testWidgets('a finger that turns back before it lifts leaves the page '
      'where it is', (tester) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: page,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: PlanStopList(tags: _tags(stops), formatDepth: _metres),
              ),
              const SizedBox(height: 4000),
            ],
          ),
        ),
      ),
    );

    // Past the list's end, so the page moves, then back down a little: the
    // list scrolls back and takes the rest, and the page keeps no flick.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PlanStopList)),
    );
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final pushed = page.offset;
    expect(pushed, greaterThan(0));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(page.offset, pushed);
  });

  testWidgets('a list that goes mid-swipe lets the page go', (tester) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    final showList = ValueNotifier(true);
    addTearDown(showList.dispose);
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: page,
            children: [
              ValueListenableBuilder(
                valueListenable: showList,
                builder: (context, show, _) => SizedBox(
                  height: 200,
                  child: show
                      ? PlanStopList(tags: _tags(stops), formatDepth: _metres)
                      : null,
                ),
              ),
              const SizedBox(height: 4000),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PlanStopList)),
    );
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(page.offset, greaterThan(0));
    // The plan changes under the finger and the list has no room any more.
    showList.value = false;
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The page is free again: a drag of its own moves it.
    final before = page.offset;
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(page.offset, greaterThan(before));
  });

  testWidgets('a page that takes no drags is not moved', (tester) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    final stops = [for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: page,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Align(
                alignment: Alignment.topRight,
                child: PlanStopList(tags: _tags(stops), formatDepth: _metres),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PlanStopList), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(page.offset, 0);
  });

  testWidgets('a new stop set opens at the shallow end, the same one keeps '
      'its place', (tester) async {
    final deep = _tags([for (var d = 42; d >= 3; d -= 3) (d.toDouble(), 1)]);
    final deeper = _tags([for (var d = 45; d >= 3; d -= 3) (d.toDouble(), 2)]);
    Future<void> show(List<PlanStopTag> tags) => tester.pumpWidget(
      _host(PlanStopList(tags: tags, formatDepth: _metres)),
    );
    ScrollPosition position() =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position;

    await show(deep);
    await tester.drag(find.byType(PlanStopList), const Offset(0, -60));
    await tester.pumpAndSettle();
    final scrolled = position().pixels;
    expect(scrolled, greaterThan(0));

    // The same stops rebuilt (an unrelated rebuild of the readouts).
    await show([...deep]);
    expect(position().pixels, scrolled);

    // A preview toggled or the plan edited.
    await show(deeper);
    await tester.pumpAndSettle();
    expect(position().pixels, 0);
  });
}
