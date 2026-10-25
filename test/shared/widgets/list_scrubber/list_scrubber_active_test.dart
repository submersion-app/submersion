import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

import 'scrubber_hover.dart';

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  Widget host({double width = 800, ValueChanged<bool>? onActiveChanged}) =>
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 600,
              width: width,
              child: ListScrubber(
                controller: controller,
                slotCount: 200,
                loadedSlotCount: 200,
                labelFor: (slot) => 'Slot $slot',
                markers: const [
                  ScrubberMarker(slot: 0, label: 'Top'),
                  ScrubberMarker(slot: 150, label: 'Low'),
                ],
                onScrubEnd: (_) {},
                onActiveChanged: onActiveChanged,
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
      );

  const quick = Duration(milliseconds: 20);

  testWidgets('flipping active faster than the panel fades throws nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final inside = scrubberThumbHoverPoint(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump(quick);

    for (var i = 0; i < 4; i++) {
      await mouse.moveTo(inside);
      await tester.pump(quick);
      expect(tester.takeException(), isNull);
      await mouse.moveTo(Offset.zero);
      await tester.pump(quick);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpAndSettle();
    expect(find.byKey(ListScrubber.panelKey), findsNothing);
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('resizing the host while hovered throws nothing', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hoverScrubberThumb(tester);
    expect(find.byKey(ListScrubber.panelKey), findsOneWidget);

    for (final width in <double>[760, 700, 790, 640, 800, 720, 770, 600, 800]) {
      await tester.pumpWidget(host(width: width));
      await mouse.moveBy(Offset.zero);
      await tester.pump(quick);
      expect(tester.takeException(), isNull);
    }

    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  });

  Future<TestGesture> grabThumb(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -10));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    return gesture;
  }

  testWidgets('reports active on drag start and inactive after release', (
    tester,
  ) async {
    final reports = <bool>[];
    await tester.pumpWidget(host(onActiveChanged: reports.add));
    await tester.pump();

    final gesture = await grabThumb(tester);
    expect(reports, [true]);

    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(reports, [true]);

    await gesture.up();
    await tester.pump();
    await tester.pump(ListScrubber.idleHide * 2);
    expect(reports, [true, false]);
  });

  testWidgets('reports a hover in and out once each', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(host(onActiveChanged: reports.add));
    await tester.pump();
    final mouse = await hoverScrubberThumb(tester);
    // Off the thumb but still over the panel.
    await mouse.moveTo(scrubberThumbHoverPoint(tester) + const Offset(-8, 100));
    await tester.pumpAndSettle();
    expect(reports, [true]);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(reports, [true, false]);
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a held mouse button sweeping across the strip stays idle', (
    tester,
  ) async {
    final reports = <bool>[];
    await tester.pumpWidget(host(onActiveChanged: reports.add));
    await tester.pump();
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.down(const Offset(400, 400));
    await tester.pump(quick);

    for (final x in <double>[700, 760, 790, 799, 770, 740, 700, 780, 600]) {
      await mouse.moveTo(Offset(x, 400));
      await tester.pump(quick);
      expect(find.byKey(ListScrubber.panelKey), findsNothing);
    }
    await mouse.up();
    await tester.pumpAndSettle();
    expect(reports, isEmpty);
    expect(find.byKey(ListScrubber.panelKey), findsNothing);
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('hovering resumes once a held button is released on the strip', (
    tester,
  ) async {
    final reports = <bool>[];
    await tester.pumpWidget(host(onActiveChanged: reports.add));
    await tester.pump();
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.down(const Offset(400, 400));
    final onThumb = scrubberThumbHoverPoint(tester);
    await mouse.moveTo(onThumb);
    await tester.pump(quick);
    await mouse.up();
    await tester.pump(quick);
    expect(reports, isEmpty);

    await mouse.moveTo(onThumb + const Offset(0, 1));
    await tester.pumpAndSettle();
    expect(reports, [true]);
    expect(find.byKey(ListScrubber.panelKey), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(reports, [true, false]);
    await mouse.removePointer();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('ordinary scrolling reports nothing', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(host(onActiveChanged: reports.add));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
    }
    await tester.pump(ListScrubber.idleHide * 2);
    expect(reports, isEmpty);
  });
}
