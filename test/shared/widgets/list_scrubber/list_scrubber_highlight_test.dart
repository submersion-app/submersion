import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_tick_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

import 'scrubber_hover.dart';

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  const tickColor = Color(0xFFEF5350);
  const favourites = [3, 120, 121, 199];

  Widget host({
    int? highlightSlot,
    List<int> ticks = favourites,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 600,
            width: 800,
            child: ListScrubber(
              controller: controller,
              slotCount: 200,
              loadedSlotCount: 200,
              labelFor: (slot) => 'Slot $slot',
              markers: const [ScrubberMarker(slot: 0, label: 'Top')],
              highlightSlot: highlightSlot,
              highlightTicks: ticks,
              highlightTickColor: tickColor,
              onScrubEnd: (_) {},
              child: ListView.builder(
                controller: controller,
                itemCount: 200,
                itemExtent: 50,
                itemBuilder: (_, i) => Text('Row $i'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Finder tickPaint() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is ListScrubberTickPainter,
  );

  /// The painted ticks in global coordinates.
  List<Rect> tickRects(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(tickPaint());
    final box = tester.getRect(tickPaint());
    return [
      for (final r in (paint.painter! as ListScrubberTickPainter).rects(
        box.size,
      ))
        r.shift(box.topLeft),
    ];
  }

  Rect thumbRect(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byKey(ListScrubber.thumbKey),
      matching: find.byType(ListScrubberHandle),
    ),
  );

  Future<TestGesture> hover(WidgetTester tester) => hoverScrubberThumb(tester);

  Future<void> leave(WidgetTester tester, TestGesture mouse) async {
    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  }

  Future<void> scroll(WidgetTester tester) async {
    controller.jumpTo(500);
    await tester.pump();
  }

  group('selected-dive dot', () {
    Rect dot(WidgetTester tester) =>
        tester.getRect(find.byKey(ListScrubber.highlightKey));

    testWidgets('sits on the track at the selected slot', (tester) async {
      await tester.pumpWidget(host(highlightSlot: 120));
      await tester.pump();
      final mouse = await hover(tester);
      final y = trackForSlot(slot: 120, trackExtent: 552, slotCount: 200);
      final rect = dot(tester);
      expect(rect.center.dy, closeTo(y + 24, 0.01));
      expect(rect.width, 6);
      expect(rect.height, 6);
      final thumb = tester.getRect(
        find.descendant(
          of: find.byKey(ListScrubber.thumbKey),
          matching: find.byType(ListScrubberHandle),
        ),
      );
      expect(rect.center.dx, closeTo(thumb.center.dx, 1.01));
      final box =
          tester
                  .widget<DecoratedBox>(find.byKey(ListScrubber.highlightKey))
                  .decoration
              as BoxDecoration;
      final context = tester.element(find.byType(ListScrubber));
      expect(box.color, Theme.of(context).colorScheme.primary);
      expect(box.shape, BoxShape.circle);
      await leave(tester, mouse);
    });

    testWidgets('no dot without a selection', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      final mouse = await hover(tester);
      expect(find.byKey(ListScrubber.highlightKey), findsNothing);
      await leave(tester, mouse);
    });

    testWidgets('no dot for a slot past the track', (tester) async {
      await tester.pumpWidget(host(highlightSlot: 200));
      await tester.pump();
      final mouse = await hover(tester);
      expect(find.byKey(ListScrubber.highlightKey), findsNothing);
      await leave(tester, mouse);
    });

    testWidgets('mirrors to the left edge in RTL', (tester) async {
      await tester.pumpWidget(
        host(highlightSlot: 120, direction: TextDirection.rtl),
      );
      await tester.pump();
      final mouse = await hover(tester);
      expect(dot(tester).center.dx, closeTo(2, 1.01));
      await leave(tester, mouse);
    });

    testWidgets('shows beside the slim thumb while idle', (tester) async {
      await tester.pumpWidget(host(highlightSlot: 120));
      await tester.pump();
      await scroll(tester);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(ListScrubber.panelKey), findsNothing);
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(ListScrubber.highlightKey),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(opacity(), 1);
      await tester.pump(ListScrubber.idleHide);
      await tester.pump(const Duration(milliseconds: 250));
      expect(opacity(), 0);
    });
  });

  group('highlight ticks', () {
    testWidgets('paint in the panel at their track positions while active', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pump();
      final mouse = await hover(tester);

      expect(
        find.ancestor(
          of: tickPaint(),
          matching: find.byKey(ListScrubber.panelKey),
        ),
        findsOneWidget,
      );
      final painter =
          tester.widget<CustomPaint>(tickPaint()).painter!
              as ListScrubberTickPainter;
      expect(painter.ticks, favourites);
      expect(painter.color, tickColor);
      final rects = tickRects(tester);
      expect(rects, hasLength(favourites.length));
      for (var i = 0; i < favourites.length; i++) {
        final y = trackForSlot(
          slot: favourites[i],
          trackExtent: 552,
          slotCount: 200,
        );
        expect(rects[i].center.dy, closeTo(y + 24, 0.01));
        expect(rects[i].width, ListScrubberTickPainter.length);
        expect(rects[i].height, ListScrubberTickPainter.thickness);
      }
      await leave(tester, mouse);
    });

    testWidgets('sit in a column just beside the thumb track', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      final mouse = await hover(tester);
      final thumb = thumbRect(tester);
      for (final r in tickRects(tester)) {
        expect(r.right, lessThanOrEqualTo(thumb.left));
        expect(thumb.left - r.right, lessThanOrEqualTo(3));
      }
      await leave(tester, mouse);
    });

    testWidgets('do not paint while idle', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await scroll(tester);
      expect(find.byKey(ListScrubber.thumbKey), findsOneWidget);
      expect(tickPaint(), findsNothing);
      await tester.pump(ListScrubber.idleHide);
    });

    testWidgets('are left out when there are none', (tester) async {
      await tester.pumpWidget(host(ticks: const []));
      await tester.pump();
      final mouse = await hover(tester);
      expect(tickPaint(), findsNothing);
      await leave(tester, mouse);
    });

    testWidgets('mirror beside the thumb on the left in RTL', (tester) async {
      await tester.pumpWidget(host(direction: TextDirection.rtl));
      await tester.pump();
      final mouse = await hover(tester);
      final thumb = thumbRect(tester);
      expect(thumb.left, lessThan(20));
      for (final r in tickRects(tester)) {
        expect(r.left, greaterThanOrEqualTo(thumb.right));
        expect(r.left - thumb.right, lessThanOrEqualTo(3));
        expect(r.width, ListScrubberTickPainter.length);
      }
      await leave(tester, mouse);
    });

    testWidgets('only paint, so a tap on them reaches the row', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              width: 800,
              child: ListScrubber(
                controller: controller,
                slotCount: 200,
                loadedSlotCount: 200,
                labelFor: (slot) => 'Slot $slot',
                markers: const [],
                highlightTicks: const [180],
                onScrubEnd: (_) {},
                child: ListView.builder(
                  controller: controller,
                  itemCount: 200,
                  itemExtent: 50,
                  itemBuilder: (_, i) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => tapped = i,
                    child: Text('Row $i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final mouse = await hover(tester);
      final tick = tickRects(tester).single;
      await tester.tapAt(tick.center);
      await tester.pump();
      expect(tapped, (tick.center.dy / 50).floor());
      await leave(tester, mouse);
    });

    test('repaint only when their inputs change', () {
      ListScrubberTickPainter painter(List<int> ticks) =>
          ListScrubberTickPainter(
            ticks: ticks,
            slotCount: 200,
            trackExtent: 398,
            offset: 24,
            endInset: 4,
            color: tickColor,
            textDirection: TextDirection.ltr,
          );
      final a = painter(favourites);
      expect(a.shouldRepaint(painter(favourites)), isFalse);
      expect(a.shouldRepaint(painter([...favourites])), isTrue);
    });
  });
}
