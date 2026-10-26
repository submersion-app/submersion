import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_context_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_density_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

import 'scrubber_hover.dart';

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  const bins = [
    ScrubberDensityBin(firstSlot: 0, lastSlot: 49, count: 50),
    ScrubberDensityBin(firstSlot: 50, lastSlot: 50, count: 1),
    ScrubberDensityBin(firstSlot: 51, lastSlot: 120, count: 70),
    ScrubberDensityBin(firstSlot: 121, lastSlot: 199, count: 79),
  ];
  const markers = [
    ScrubberMarker(slot: 30, label: '2019'),
    ScrubberMarker(slot: 100, label: 'Sept'),
    ScrubberMarker(slot: 170, label: '2018'),
  ];

  Widget host({
    List<ScrubberDensityBin> density = bins,
    TextDirection direction = TextDirection.ltr,
    ValueChanged<int>? onRowTap,
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
              markers: markers,
              segments: const [
                ScrubberSegment(
                  firstSlot: 0,
                  lastSlot: 199,
                  color: Color(0xFF7D5260),
                ),
              ],
              density: density,
              onScrubEnd: (_) {},
              child: ListView.builder(
                controller: controller,
                itemCount: 200,
                itemExtent: 50,
                itemBuilder: (_, i) => onRowTap == null
                    ? Text('Row $i')
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onRowTap(i),
                        child: Text('Row $i'),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Finder densityPaint() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is ListScrubberDensityPainter,
  );

  ListScrubberDensityPainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(densityPaint()).painter!
          as ListScrubberDensityPainter;

  List<Rect> bars(WidgetTester tester) {
    final box = tester.getRect(densityPaint());
    return [
      for (final r in painterOf(tester).bars(box.size)) r.shift(box.topLeft),
    ];
  }

  double y(int slot) =>
      24 + trackForSlot(slot: slot, trackExtent: 552, slotCount: 200);

  Future<TestGesture> hover(WidgetTester tester) => hoverScrubberThumb(tester);

  Future<void> leave(WidgetTester tester, TestGesture mouse) async {
    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  }

  testWidgets('bars paint in the panel while active, one per bin', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hover(tester);

    expect(
      find.ancestor(
        of: densityPaint(),
        matching: find.byKey(ListScrubber.panelKey),
      ),
      findsOneWidget,
    );
    expect(painterOf(tester).bins, bins);
    final rects = bars(tester);
    expect(rects, hasLength(4));
    expect(rects[0].top, closeTo(y(0), 0.01));
    expect(rects[0].bottom, closeTo(y(49), 0.01));
    expect(rects[2].top, closeTo(y(51), 0.01));
    expect(rects[3].width, ListScrubberDensityPainter.maxLength);
    expect(rects[2].width, closeTo(12 * 70 / 79, 0.01));
    await leave(tester, mouse);
  });

  testWidgets('nothing paints while idle', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    controller.jumpTo(500);
    await tester.pump();
    expect(find.byKey(ListScrubber.thumbKey), findsOneWidget);
    expect(densityPaint(), findsNothing);
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('no bins, no column and no extra width', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    var mouse = await hover(tester);
    final withBins = tester.getRect(find.byKey(ListScrubber.panelKey)).width;
    await leave(tester, mouse);

    await tester.pumpWidget(host(density: const []));
    await tester.pump();
    mouse = await hover(tester);
    expect(densityPaint(), findsNothing);
    expect(
      tester.getRect(find.byKey(ListScrubber.panelKey)).width,
      withBins - ListScrubberPanel.densityColumn,
    );
    await leave(tester, mouse);
  });

  testWidgets('the column sits beside the context column, clear of markers', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hover(tester);
    final panel = tester.getRect(find.byKey(ListScrubber.panelKey));
    final context = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ListScrubberContextPainter,
      ),
    );
    final contextRight =
        context.left +
        ListScrubberContextPainter.inset +
        ListScrubberContextPainter.width;
    final labels = [
      for (final e in find.byKey(ListScrubberPanel.labelBackingKey).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(labels, isNotEmpty);
    for (final bar in bars(tester)) {
      expect(bar.left, panel.left + ListScrubberDensityPainter.start);
      expect(bar.left, greaterThan(contextRight));
      for (final label in labels) {
        expect(bar.right, lessThan(label.left));
      }
    }
    await leave(tester, mouse);
  });

  testWidgets('bars leave out the value band', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    controller.jumpTo(10);
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 250));
    await tester.pump();

    final band = tester.getRect(find.byKey(ListScrubber.currentBandKey));
    final rects = bars(tester);
    for (final bar in rects) {
      expect(
        bar.bottom <= band.top || bar.top >= band.bottom,
        isTrue,
        reason: '$bar overlaps $band',
      );
    }
    expect(rects.where((r) => r.bottom == band.top), hasLength(1));
    expect(rects.where((r) => r.top == band.bottom), hasLength(1));

    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a tap on a bar reaches the row', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(host(onRowTap: (i) => tapped = i));
    await tester.pump();
    final mouse = await hover(tester);
    final bar = bars(tester).first;
    await tester.tapAt(bar.center);
    await tester.pump();
    expect(tapped, (bar.center.dy / 50).floor());
    await leave(tester, mouse);
  });

  testWidgets('the column mirrors to the panel start edge in RTL', (
    tester,
  ) async {
    await tester.pumpWidget(host(direction: TextDirection.rtl));
    await tester.pump();
    final mouse = await hover(tester);
    final panel = tester.getRect(find.byKey(ListScrubber.panelKey));
    expect(panel.left, 0);
    final rects = bars(tester);
    for (final bar in rects) {
      expect(bar.right, panel.right - ListScrubberDensityPainter.start);
    }
    expect(rects[3].width, ListScrubberDensityPainter.maxLength);
    await leave(tester, mouse);
  });

  group('painter', () {
    ListScrubberDensityPainter painter({
      List<ScrubberDensityBin> bins = bins,
      ({double top, double bottom})? clear,
    }) => ListScrubberDensityPainter(
      bins: bins,
      slotCount: 200,
      trackExtent: 400,
      offset: 24,
      color: const Color(0x59000000),
      textDirection: TextDirection.ltr,
      clear: clear,
    );

    test('a one-dive bin beside a busy one keeps a minimum length', () {
      final rects = painter().bars(const Size(83, 448));
      expect(rects[1].width, ListScrubberDensityPainter.minLength);
      expect(rects[1].height, greaterThanOrEqualTo(1));
      expect(rects[3].width, ListScrubberDensityPainter.maxLength);
    });

    test('repaints only when its inputs change', () {
      final a = painter();
      expect(a.shouldRepaint(painter()), isFalse);
      expect(a.shouldRepaint(painter(bins: [...bins])), isTrue);
      expect(a.shouldRepaint(painter(clear: (top: 10, bottom: 30))), isTrue);
    });
  });
}
