import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_geometry.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  Widget host({
    int rows = 200,
    int? slotCount,
    int? loadedSlotCount,
    void Function(int)? onEnd,
    String? busy,
    String Function(int)? label,
    double? width,
    TextDirection direction = TextDirection.ltr,
    void Function(int)? onRowTap,
  }) => MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 600,
            width: width ?? 800,
            child: ListScrubber(
              controller: controller,
              slotCount: slotCount ?? rows,
              loadedSlotCount: loadedSlotCount ?? rows,
              labelFor: label ?? (slot) => 'Slot $slot',
              markers: const [
                ScrubberMarker(slot: 0, label: 'Top'),
                ScrubberMarker(slot: 150, label: 'Low'),
              ],
              onScrubEnd: onEnd ?? (_) {},
              busyLabel: busy,
              child: ListView.builder(
                controller: controller,
                itemCount: rows,
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

  bool insideRect(Rect outer, Rect inner) =>
      inner.left >= outer.left - 0.01 &&
      inner.right <= outer.right + 0.01 &&
      inner.top >= outer.top - 0.01 &&
      inner.bottom <= outer.bottom + 0.01;

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(ListScrubber.thumbKey),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('absent for a short list', (tester) async {
    await tester.pumpWidget(host(rows: 20));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(find.byKey(ListScrubber.thumbKey), findsNothing);
  });

  testWidgets('appears on scroll and fades out when idle', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(opacity(tester), 0);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(opacity(tester), 1);

    await tester.pump(
      ListScrubber.idleHide + const Duration(milliseconds: 100),
    );
    expect(opacity(tester), 0);
  });

  testWidgets('dragging shows the value, follows live, reports the slot', (
    tester,
  ) async {
    int? ended;
    await tester.pumpWidget(host(onEnd: (s) => ended = s));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 276));
    await tester.pump();

    expect(find.byKey(ListScrubber.currentValueKey), findsOneWidget);
    expect(find.textContaining('Slot '), findsOneWidget);
    expect(find.text('Top'), findsOneWidget);
    expect(controller.offset, greaterThan(1000));

    await gesture.up();
    await tester.pump();
    expect(ended, isNotNull);
    expect(ended, inInclusiveRange(90, 110));
  });

  testWidgets('beyond the loaded rows only the value moves', (tester) async {
    int? ended;
    await tester.pumpWidget(
      host(
        rows: 100,
        slotCount: 400,
        loadedSlotCount: 100,
        onEnd: (s) => ended = s,
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final before = controller.offset;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 600));
    await tester.pump();
    expect(controller.offset, closeTo(before, 1));
    expect(find.text('Slot 399'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(ended, 399);
  });

  testWidgets('a drop on rows that loaded mid-hold brings the list to it', (
    tester,
  ) async {
    int? ended;
    await tester.pumpWidget(
      host(
        rows: 100,
        slotCount: 400,
        loadedSlotCount: 100,
        onEnd: (s) => ended = s,
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final before = controller.offset;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 208));
    await tester.pump();
    expect(controller.offset, closeTo(before, 1));

    await tester.pumpWidget(
      host(
        rows: 200,
        slotCount: 400,
        loadedSlotCount: 200,
        onEnd: (s) => ended = s,
      ),
    );
    await gesture.up();
    await tester.pump();

    expect(ended, inInclusiveRange(100, 199));
    expect(
      controller.offset,
      closeTo(
        scrollForSlot(
          slot: ended!,
          maxScrollExtent: controller.position.maxScrollExtent,
          loadedSlotCount: 200,
        ),
        0.01,
      ),
    );
  });

  testWidgets('a drag from a busy slot the list never showed follows it', (
    tester,
  ) async {
    int? ended;
    Widget at(int loaded) => host(
      rows: loaded,
      slotCount: 400,
      loadedSlotCount: loaded,
      busy: 'Loading',
      onEnd: (s) => ended = s,
    );
    await tester.pumpWidget(at(100));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    var gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 208));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    final busySlot = ended!;
    expect(busySlot, greaterThanOrEqualTo(100));
    final before = controller.offset;

    gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(controller.offset, before);

    await tester.pumpWidget(at(200));
    await gesture.up();
    await tester.pump();

    expect(ended, busySlot);
    expect(
      controller.offset,
      closeTo(
        scrollForSlot(
          slot: busySlot,
          maxScrollExtent: controller.position.maxScrollExtent,
          loadedSlotCount: 200,
        ),
        0.01,
      ),
    );
  });

  testWidgets('dragging back after an overshoot moves the slot at once', (
    tester,
  ) async {
    int? ended;
    await tester.pumpWidget(host(onEnd: (s) => ended = s));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 300));
    await gesture.moveBy(const Offset(0, 600));
    await tester.pump();
    expect(find.text('Slot 199'), findsOneWidget);

    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    expect(find.text('Slot 199'), findsNothing);

    await gesture.up();
    await tester.pump();
    expect(ended, lessThan(199));
  });

  testWidgets('a held slot is clamped when the slots shrink mid-drag', (
    tester,
  ) async {
    int? ended;
    await tester.pumpWidget(host(onEnd: (s) => ended = s));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 540));
    await tester.pump();

    await tester.pumpWidget(host(slotCount: 40, onEnd: (s) => ended = s));
    expect(find.text('Slot 39'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(ended, 39);
  });

  testWidgets('a busy label keeps it visible and shows in the panel', (
    tester,
  ) async {
    await tester.pumpWidget(host(busy: 'Loading'));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump(ListScrubber.idleHide * 2);
    expect(opacity(tester), 1);
    expect(find.text('Loading'), findsOneWidget);
    final value = find.byKey(ListScrubber.currentValueKey);
    expect(tester.widget<Text>(value).data, 'Loading');
    final rect = tester.getRect(find.byKey(ListScrubber.panelKey));
    final band = tester.getRect(find.byKey(ListScrubber.currentBandKey));
    expect(rect.width, ListScrubberPanel.width);
    expect(band.left, lessThan(rect.left));
    expect(band.right, rect.right);
    expect(insideRect(band, tester.getRect(value)), isTrue);
    expect(
      insideRect(
        band,
        tester.getRect(find.byKey(ListScrubber.currentMarkerKey)),
      ),
      isTrue,
    );
  });

  testWidgets('the list keeps its scroll offset when the scrubber appears', (
    tester,
  ) async {
    await tester.pumpWidget(host(rows: 30));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.byKey(ListScrubber.thumbKey), findsNothing);
    final before = controller.offset;

    await tester.pumpWidget(host(rows: 30, slotCount: 400));
    await tester.pump();
    expect(find.byKey(ListScrubber.thumbKey), findsOneWidget);
    expect(controller.offset, before);
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('disposing mid-fade leaves no timer behind', (tester) async {
    await tester.pumpWidget(host());
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(find.byType(ListScrubber), findsNothing);
  });

  testWidgets('a drag whose thumb unmounts is dropped', (tester) async {
    int? ended;
    await tester.pumpWidget(host(onEnd: (s) => ended = s));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 276));
    await tester.pump();
    expect(find.byKey(ListScrubber.currentValueKey), findsOneWidget);

    await tester.pumpWidget(host(slotCount: 5, onEnd: (s) => ended = s));
    await gesture.up();
    await tester.pumpWidget(host(slotCount: 200, onEnd: (s) => ended = s));
    await tester.pump(ListScrubber.idleHide * 3);

    expect(ended, isNull);
    expect(find.byKey(ListScrubber.currentValueKey), findsNothing);
    expect(opacity(tester), 0);

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();
    expect(opacity(tester), 1);
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a hover whose strip unmounts is dropped', (tester) async {
    await tester.pumpWidget(host());
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await tester.pump();

    await tester.pumpWidget(host(slotCount: 5));
    await mouse.moveTo(Offset.zero);
    await tester.pumpWidget(host(slotCount: 200));
    await tester.pump(ListScrubber.idleHide * 3);
    expect(opacity(tester), 0);
    await mouse.removePointer();
  });

  double expectedThumbTop(WidgetTester tester) {
    final position = controller.position;
    final slot = slotForScroll(
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
      loadedSlotCount: 200,
    );
    return tester.getTopLeft(find.byType(ListScrubber)).dy +
        trackForSlot(slot: slot, trackExtent: 600 - 48.0, slotCount: 200);
  }

  Future<void> scrollFar(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the thumb follows ordinary scrolling', (tester) async {
    await tester.pumpWidget(host());
    await scrollFar(tester);
    expect(controller.offset, greaterThan(3000));
    expect(
      tester.getTopLeft(find.byKey(ListScrubber.thumbKey)).dy,
      closeTo(expectedThumbTop(tester), 1),
    );
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('grabbing the thumb after a scroll keeps the list in place', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await scrollFar(tester);
    final before = controller.offset;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    // A jump snaps to a slot; one slot is 9400 / 199 px of scroll and 2 px
    // of track is under two slots.
    expect(find.byKey(ListScrubber.currentValueKey), findsOneWidget);
    expect(controller.offset, closeTo(before, 100));
    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('hides the platform scrollbar on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(host());
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.byKey(ListScrubber.thumbKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListScrubber),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollbar || w is RawScrollbar,
          ),
        ),
        findsNothing,
      );
      await tester.pump(ListScrubber.idleHide);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final width in <double>[800, 360, 120]) {
    testWidgets('a long value sticks out of the panel within limits at $width '
        'px', (tester) async {
      await tester.pumpWidget(
        host(width: width, label: (slot) => 'A very long dive site name ' * 6),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -10));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ListScrubber.thumbKey)),
      );
      await gesture.moveBy(const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(ListScrubber.panelKey));
      final band = tester.getRect(find.byKey(ListScrubber.currentBandKey));
      final area = tester.getRect(find.byType(ListScrubber));
      expect(rect.width, ListScrubberPanel.width);
      expect(rect.right, area.right);
      expect(band.right, area.right);
      expect(band.left, lessThan(rect.left));
      expect(band.width, lessThanOrEqualTo(ListScrubberPanel.maxBandWidth));
      expect(band.width, lessThanOrEqualTo(area.width - 16));
      expect(
        band.width,
        width > 200 ? ListScrubberPanel.maxBandWidth : area.width - 16,
      );
      final value = find.byKey(ListScrubber.currentValueKey);
      final text = tester.widget<Text>(value);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(insideRect(band, tester.getRect(value)), isTrue);
      await gesture.up();
      await tester.pump(ListScrubber.idleHide);
    });
  }

  testWidgets('the panel keeps its width from the first frame of a drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(label: (slot) => 'A very long dive site name ' * 6),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    double width() => tester.getSize(find.byKey(ListScrubber.panelKey)).width;
    double bandWidth() =>
        tester.getSize(find.byKey(ListScrubber.currentBandKey)).width;
    expect(width(), ListScrubberPanel.width);
    expect(bandWidth(), ListScrubberPanel.maxBandWidth);
    await tester.pump(const Duration(milliseconds: 60));
    expect(width(), ListScrubberPanel.width);
    await tester.pumpAndSettle();
    expect(width(), ListScrubberPanel.width);
    expect(bandWidth(), ListScrubberPanel.maxBandWidth);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a short value keeps the band inside the panel', (tester) async {
    await tester.pumpWidget(
      host(label: (slot) => slot < 60 ? 'A long dive site name' : 'B'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.text('A long dive site name'), findsOneWidget);
    Rect rect() => tester.getRect(find.byKey(ListScrubber.panelKey));
    Rect band() => tester.getRect(find.byKey(ListScrubber.currentBandKey));
    expect(band().left, lessThan(rect().left));

    await gesture.moveBy(const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(rect().width, ListScrubberPanel.width);
    expect(insideRect(rect(), band()), isTrue);
    expect(
      insideRect(
        band(),
        tester.getRect(find.byKey(ListScrubber.currentValueKey)),
      ),
      isTrue,
    );
    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });

  Finder panel() => find.byKey(ListScrubber.panelKey);

  Finder handle() => find.descendant(
    of: find.descendant(
      of: find.byKey(ListScrubber.thumbKey),
      matching: find.byType(AnimatedContainer),
    ),
    matching: find.byType(DecoratedBox),
  );

  Future<TestGesture> hoverStrip(WidgetTester tester) async {
    final area = tester.getRect(find.byType(ListScrubber));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(area.right - 10, area.top + 400));
    await tester.pumpAndSettle();
    return mouse;
  }

  testWidgets('idle scrolling shows only a slim thumb, no panel', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(opacity(tester), 1);
    expect(panel(), findsNothing);
    expect(find.text('Top'), findsNothing);
    final slim = tester.getRect(handle());
    final area = tester.getRect(find.byType(ListScrubber));
    expect(slim.width, 4);
    expect(slim.height, 48);
    expect(slim.left, greaterThanOrEqualTo(area.right - 8));
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a hover over the strip shows the panel and markers', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hoverStrip(tester);
    expect(opacity(tester), 1);
    expect(panel(), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
    await tester.pumpAndSettle();
    expect(panel(), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('the hover stays active across the whole panel', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hoverStrip(tester);
    final rect = tester.getRect(panel());
    await mouse.moveTo(Offset(rect.left + 4, rect.center.dy));
    await tester.pumpAndSettle();
    expect(panel(), findsOneWidget);
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('markers sit inside the panel', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hoverStrip(tester);
    final rect = tester.getRect(panel());
    final area = tester.getRect(find.byType(ListScrubber));
    expect(rect.width, 64);
    expect(rect.right, area.right);
    expect(rect.height, area.height);
    for (final label in ['Low']) {
      final text = tester.getRect(find.text(label));
      expect(text.left, greaterThanOrEqualTo(rect.left));
      expect(text.right, lessThanOrEqualTo(rect.right));
      expect(text.center.dx, closeTo(rect.center.dx, 1));
    }
    expect(
      find.ancestor(of: find.text('Low'), matching: panel()),
      findsOneWidget,
    );
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a marker under the handle is hidden', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hoverStrip(tester);
    expect(find.text('Top'), findsNothing);
    expect(find.text('Low'), findsOneWidget);
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('dragging shows the value on a band level with the thumb', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 276));
    await tester.pumpAndSettle();

    expect(panel(), findsOneWidget);
    expect(find.text('Top'), findsOneWidget);
    final rect = tester.getRect(panel());
    final thumb = tester.getRect(find.byKey(ListScrubber.thumbKey));
    final valueFinder = find.byKey(ListScrubber.currentValueKey);
    final label = tester.widget<Text>(valueFinder).data!;
    final shown = find.text(label);
    expect(shown, findsOneWidget);
    final band = tester.getRect(find.byKey(ListScrubber.currentBandKey));
    expect(rect.width, ListScrubberPanel.width);
    expect(band.left, lessThan(rect.left));
    expect(band.right, rect.right);
    expect(band.center.dy, closeTo(thumb.center.dy, 1));
    expect(insideRect(band, tester.getRect(shown)), isTrue);
    final value = tester.getRect(valueFinder);
    final marker = tester.getRect(find.byKey(ListScrubber.currentMarkerKey));
    expect(insideRect(band, value), isTrue);
    expect(insideRect(band, marker), isTrue);
    expect(value.center.dy, closeTo(thumb.center.dy, 2));
    expect(marker.center.dy, closeTo(thumb.center.dy, 2));
    expect(marker.height, inInclusiveRange(1.5, 2));
    final slim = tester.getRect(handle());
    expect(marker.left, greaterThanOrEqualTo(value.right));
    expect(marker.right, lessThanOrEqualTo(slim.left));
    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('the active thumb stays a slim pill with a wide hit area', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 100));
    await tester.pumpAndSettle();

    final area = tester.getRect(find.byType(ListScrubber));
    final slim = tester.getRect(handle());
    expect(slim.width, lessThanOrEqualTo(10));
    expect(slim.height, inInclusiveRange(40, 48));
    expect(slim.right, greaterThanOrEqualTo(area.right - 4));
    expect(
      find.descendant(
        of: find.byKey(ListScrubber.thumbKey),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(tester.getSize(find.byKey(ListScrubber.thumbKey)).width, 48);
    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a tap on the panel beside the thumb reaches the row', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(host(onRowTap: (i) => tapped = i));
    await tester.pump();
    final mouse = await hoverStrip(tester);
    final rect = tester.getRect(panel());
    final thumb = tester.getRect(find.byKey(ListScrubber.thumbKey));
    final target = Offset(rect.right - 10, thumb.bottom + 200);
    await mouse.moveTo(target);
    await tester.pump();
    await mouse.down(target);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a tap on the band beside the panel reaches the row', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(host(busy: 'Loading', onRowTap: (i) => tapped = i));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final rect = tester.getRect(panel());
    final band = tester.getRect(find.byKey(ListScrubber.currentBandKey));
    expect(band.left, lessThan(rect.left - 10));
    await tester.tapAt(Offset(band.left + 4, band.center.dy));
    await tester.pump();
    expect(tapped, isNotNull);
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('right-to-left puts the thumb and panel on the left edge', (
    tester,
  ) async {
    await tester.pumpWidget(host(direction: TextDirection.rtl));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final area = tester.getRect(find.byType(ListScrubber));
    final thumb = tester.getRect(find.byKey(ListScrubber.thumbKey));
    expect(thumb.left, closeTo(area.left, 0.5));

    final gesture = await tester.startGesture(thumb.center);
    await gesture.moveBy(const Offset(0, 200));
    await tester.pumpAndSettle();
    final rect = tester.getRect(panel());
    expect(rect.left, closeTo(area.left, 0.5));
    expect(rect.width, ListScrubberPanel.width);
    final band = tester.getRect(find.byKey(ListScrubber.currentBandKey));
    expect(band.left, closeTo(area.left, 0.5));
    expect(band.right, greaterThan(rect.right));
    expect(band.center.dy, closeTo(thumb.center.dy + 200, 1));
    final value = tester.getRect(find.byKey(ListScrubber.currentValueKey));
    final marker = tester.getRect(find.byKey(ListScrubber.currentMarkerKey));
    final slim = tester.getRect(handle());
    expect(insideRect(band, value), isTrue);
    expect(insideRect(band, marker), isTrue);
    expect(slim.left, lessThanOrEqualTo(area.left + 4));
    expect(marker.left, greaterThanOrEqualTo(slim.right));
    expect(marker.right, lessThanOrEqualTo(value.left));
    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('the thumb has a 48 px wide touch target', (tester) async {
    int? ended;
    await tester.pumpWidget(host(onEnd: (s) => ended = s));
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final thumb = tester.getRect(find.byKey(ListScrubber.thumbKey));
    expect(thumb.width, 48);
    expect(thumb.right, tester.getRect(find.byType(ListScrubber)).right);

    final gesture = await tester.startGesture(
      thumb.centerLeft + const Offset(3, 0),
    );
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(ended, isNotNull);
    await tester.pump(ListScrubber.idleHide);
  });
}
