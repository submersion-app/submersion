import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

import 'scrubber_hover.dart';

/// Counts how often the panel walks the markers.
class _CountingMarkers extends ListBase<ScrubberMarker> {
  _CountingMarkers(this._items);

  final List<ScrubberMarker> _items;
  int walks = 0;

  @override
  int get length => _items.length;

  @override
  set length(int value) => throw UnsupportedError('read only');

  @override
  ScrubberMarker operator [](int index) => _items[index];

  @override
  void operator []=(int index, ScrubberMarker value) =>
      throw UnsupportedError('read only');

  @override
  Iterator<ScrubberMarker> get iterator {
    walks++;
    return _items.iterator;
  }
}

void main() {
  late ScrollController controller;
  late _CountingMarkers markers;

  setUp(() {
    controller = ScrollController();
    markers = _CountingMarkers([
      for (var i = 0; i < 200; i += 10) ScrubberMarker(slot: i, label: 'M$i'),
    ]);
  });
  tearDown(() => controller.dispose());

  Widget host() => MaterialApp(
    home: Scaffold(
      body: Align(
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
  );

  Future<TestGesture> hover(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final mouse = await hoverScrubberThumb(tester);
    expect(find.byKey(ListScrubber.panelKey), findsOneWidget);
    return mouse;
  }

  testWidgets('a resting hover walks the markers at most once', (tester) async {
    final mouse = await hover(tester);
    final before = markers.walks;

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(markers.walks, before);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  });

  testWidgets('scrolling that leaves the covered markers alone thins nothing', (
    tester,
  ) async {
    final mouse = await hover(tester);
    final before = markers.walks;

    for (var i = 0; i < 5; i++) {
      controller.jumpTo(controller.offset + 1);
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(markers.walks, before);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  });
}
