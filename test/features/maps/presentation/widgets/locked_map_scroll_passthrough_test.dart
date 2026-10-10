import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/locked_map_scroll_passthrough.dart';

void main() {
  Future<({ScrollController scroll, MapController map})> pumpLockedMap(
    WidgetTester tester, {
    Axis axis = Axis.vertical,
    VoidCallback? onPinTap,
    ScrollPhysics? physics,
  }) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final map = MapController();
    final lockedMap = SizedBox(
      width: 300,
      height: 200,
      child: LockedMapScrollPassthrough(
        child: FlutterMap(
          mapController: map,
          options: const MapOptions(
            initialCenter: LatLng(0, 0),
            initialZoom: 5,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            MarkerLayer(
              markers: [
                Marker(
                  point: const LatLng(0, 0),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    key: const ValueKey('pin'),
                    onTap: onPinTap,
                    child: const ColoredBox(color: Color(0xFF000000)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            scrollDirection: axis,
            physics: physics,
            child: axis == Axis.vertical
                ? Column(children: [lockedMap, const SizedBox(height: 3000)])
                : Row(children: [lockedMap, const SizedBox(width: 3000)]),
          ),
        ),
      ),
    );
    await tester.pump();
    return (scroll: scroll, map: map);
  }

  Future<void> trackpadScroll(
    WidgetTester tester,
    Offset at,
    Offset pan,
  ) async {
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(at);
    await tester.pump();
    await gesture.panZoomUpdate(at, pan: pan);
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pump();
  }

  testWidgets('a trackpad scroll over a locked map scrolls the page', (
    tester,
  ) async {
    final (:scroll, :map) = await pumpLockedMap(tester);
    final zoom = map.camera.zoom;
    final center = map.camera.center;

    // Fingers moving up scroll the content forward, as on a touch screen.
    await trackpadScroll(
      tester,
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(20, 20),
      const Offset(0, -120),
    );

    expect(scroll.offset, 120);
    expect(map.camera.zoom, zoom);
    expect(map.camera.center, center);
  });

  testWidgets('a trackpad scroll back up returns the page', (tester) async {
    final (:scroll, map: _) = await pumpLockedMap(tester);
    scroll.jumpTo(60);
    await tester.pump();

    // The map's top edge is now offscreen, so aim at its visible lower part.
    await trackpadScroll(
      tester,
      tester.getBottomLeft(find.byType(FlutterMap)) + const Offset(20, -20),
      const Offset(0, 40),
    );

    expect(scroll.offset, 20);
  });

  testWidgets('a horizontal scrollable takes the sideways component', (
    tester,
  ) async {
    final (:scroll, map: _) = await pumpLockedMap(
      tester,
      axis: Axis.horizontal,
    );

    await trackpadScroll(
      tester,
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(20, 20),
      const Offset(-90, -40),
    );

    expect(scroll.offset, 90);
  });

  testWidgets('a quick flick keeps the page coasting after the lift', (
    tester,
  ) async {
    final (:scroll, map: _) = await pumpLockedMap(tester);
    final at =
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(20, 20);

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(at);
    var pan = Offset.zero;
    for (var i = 1; i <= 5; i++) {
      pan += const Offset(0, -30);
      await gesture.panZoomUpdate(
        at,
        pan: pan,
        timeStamp: Duration(milliseconds: 16 * i),
      );
    }
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();

    // 150px of finger travel; the fling carries the page further, as it does
    // for a trackpad scroll anywhere else on the page.
    expect(scroll.offset, greaterThan(150));
  });

  testWidgets('a scroll view that refuses user scrolling stays put', (
    tester,
  ) async {
    final (:scroll, map: _) = await pumpLockedMap(
      tester,
      physics: const NeverScrollableScrollPhysics(),
    );

    await trackpadScroll(
      tester,
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(20, 20),
      const Offset(0, -120),
    );

    expect(scroll.offset, 0);
  });

  testWidgets('a vertical scroll skips a nearer horizontal scrollable', (
    tester,
  ) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    final inner = ScrollController();
    addTearDown(inner.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: outer,
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    controller: inner,
                    scrollDirection: Axis.horizontal,
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 300,
                          child: LockedMapScrollPassthrough(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(0, 0),
                                initialZoom: 5,
                                interactionOptions: InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [],
                            ),
                          ),
                        ),
                        SizedBox(width: 3000),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await trackpadScroll(
      tester,
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(20, 20),
      const Offset(0, -120),
    );

    expect(outer.offset, 120);
    expect(inner.offset, 0);
  });

  testWidgets('removing the map mid-scroll releases the page', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final showMap = ValueNotifier(true);
    addTearDown(showMap.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: showMap,
                  builder: (context, show, _) => SizedBox(
                    height: 200,
                    child: show
                        ? const LockedMapScrollPassthrough(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(0, 0),
                                initialZoom: 5,
                                interactionOptions: InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [],
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 3000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final at =
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(20, 20);

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(at);
    await gesture.panZoomUpdate(at, pan: const Offset(0, -60));
    await tester.pump();
    expect(scroll.position.isScrollingNotifier.value, isTrue);

    // The drag is cancelled with the map, so the page is not left mid-drag.
    showMap.value = false;
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();

    expect(scroll.position.isScrollingNotifier.value, isFalse);
    expect(scroll.offset, 60);
  });

  testWidgets('a trackpad click-drag scrolls the page like a touch drag', (
    tester,
  ) async {
    final (:scroll, map: _) = await pumpLockedMap(tester);
    final at =
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(20, 20);

    // An ordinary trackpad pointer, not a pan-zoom: the passthrough leaves it
    // alone and the page's own drag recognizer takes it.
    final gesture = await tester.startGesture(
      at,
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.moveBy(const Offset(0, -40));
    await gesture.up();
    await tester.pump();

    expect(scroll.offset, 40);
  });

  testWidgets('names its recognizer in diagnostics', (tester) async {
    await pumpLockedMap(tester);

    expect(
      tester.element(find.byType(LockedMapScrollPassthrough)).toStringDeep(),
      contains('trackpadScroll'),
    );
  });

  testWidgets('taps still reach widgets inside the locked map', (tester) async {
    var taps = 0;
    await pumpLockedMap(tester, onPinTap: () => taps++);

    await tester.tap(find.byKey(const ValueKey('pin')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(taps, 1);
  });
}
