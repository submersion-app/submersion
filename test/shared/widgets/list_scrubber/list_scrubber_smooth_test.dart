import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

/// The thumb and the list move together by the pixel, not a slot at a time
/// (#3665).
void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  const rowHeight = 50.0;
  const viewport = 600.0;
  const track = viewport - 48;

  var labels = 0;
  setUp(() => labels = 0);

  Widget host({required int rows, int? slotCount}) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: viewport,
          width: 800,
          child: ListScrubber(
            controller: controller,
            slotCount: slotCount ?? rows,
            loadedSlotCount: rows,
            labelFor: (slot) {
              labels++;
              return 'Slot $slot';
            },
            markers: const [ScrubberMarker(slot: 0, label: 'Top')],
            onScrubEnd: (_) {},
            child: ListView.builder(
              controller: controller,
              itemCount: rows,
              itemExtent: rowHeight,
              itemBuilder: (_, i) => Text('Row $i'),
            ),
          ),
        ),
      ),
    ),
  );

  double thumbTop(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(ListScrubber.thumbKey)).dy -
      tester.getTopLeft(find.byType(ListScrubber)).dy;

  testWidgets('the thumb moves with every pixel the list scrolls', (
    tester,
  ) async {
    // 60 rows: one slot is 552 / 59 px of track, over 9 px.
    await tester.pumpWidget(host(rows: 60));
    final maxScroll = controller.position.maxScrollExtent;

    for (final pixels in [100.0, 110.0, 117.0]) {
      controller.jumpTo(pixels);
      await tester.pump();
      expect(thumbTop(tester), closeTo(pixels / maxScroll * track, 0.01));
    }
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a dragged thumb stays under the pointer and the list follows '
      'it by the pixel', (tester) async {
    await tester.pumpWidget(host(rows: 60));
    controller.jumpTo(10);
    await tester.pump();
    final maxScroll = controller.position.maxScrollExtent;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    final top = thumbTop(tester);
    final offset = controller.offset;

    for (var step = 1; step <= 3; step++) {
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      expect(thumbTop(tester), closeTo(top + 4 * step, 0.01));
      expect(
        controller.offset,
        closeTo(offset + 4 * step * maxScroll / track, 0.01),
      );
    }
    final dropped = controller.offset;
    final droppedTop = thumbTop(tester);

    await gesture.up();
    await tester.pump();
    await tester.pump();
    expect(controller.offset, dropped);
    expect(thumbTop(tester), closeTo(droppedTop, 0.01));
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('a pointer held past the end of the track moves nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host(rows: 60));
    controller.jumpTo(10);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, track));
    await tester.pump();
    final offset = controller.offset;
    expect(offset, controller.position.maxScrollExtent);
    expect(thumbTop(tester), closeTo(track, 0.01));
    final built = labels;

    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(controller.offset, offset);
    expect(thumbTop(tester), closeTo(track, 0.01));
    // Nothing moved, so the scrubber did not rebuild for the updates.
    expect(labels, built);

    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('rows that load under a held thumb are followed on the next '
      'update, even one with no vertical move', (tester) async {
    await tester.pumpWidget(host(rows: 100, slotCount: 400));
    controller.jumpTo(10);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    final top = thumbTop(tester);

    await tester.pumpWidget(host(rows: 200, slotCount: 400));
    // Rows added off screen leave the list's extent stale until it lays
    // out again, which the first follow's jump brings about; the second
    // update then follows against the full extent.
    for (var i = 0; i < 2; i++) {
      await gesture.moveBy(const Offset(-5, 0));
      await tester.pump();
    }

    expect(thumbTop(tester), closeTo(top, 0.01));
    expect(
      controller.offset,
      closeTo(
        top / track * 399 / 199 * controller.position.maxScrollExtent,
        0.01,
      ),
    );

    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('over loaded rows of a longer list the drag still follows '
      'by the pixel', (tester) async {
    await tester.pumpWidget(host(rows: 100, slotCount: 400));
    controller.jumpTo(10);
    await tester.pump();
    final maxScroll = controller.position.maxScrollExtent;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ListScrubber.thumbKey)),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    final top = thumbTop(tester);
    final offset = controller.offset;

    await gesture.moveBy(const Offset(0, 4));
    await tester.pump();
    expect(thumbTop(tester), closeTo(top + 4, 0.01));
    // 4 px of track over 400 slots, of which 100 rows fill the scroll.
    expect(
      controller.offset,
      closeTo(offset + 4 / track * 399 / 99 * maxScroll, 0.01),
    );

    await gesture.up();
    await tester.pump(ListScrubber.idleHide);
  });
}
