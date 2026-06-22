import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';

void main() {
  Future<MapController> pumpMap(WidgetTester tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackpadZoomMap(
            controller: controller,
            child: FlutterMap(
              mapController: controller,
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 5,
                minZoom: 1,
                maxZoom: 18,
              ),
              children: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('trackpad two-finger scroll up zooms in progressively', (
    tester,
  ) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(center);
    await tester.pump();
    await gesture.panZoomUpdate(center, pan: const Offset(0, -50));
    await tester.pump();
    await gesture.panZoomUpdate(center, pan: const Offset(0, -100));
    await tester.pump();
    final mid = controller.camera.zoom;
    await gesture.panZoomUpdate(center, pan: const Offset(0, -150));
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pump();

    expect(mid, greaterThan(start));
    expect(
      controller.camera.zoom,
      greaterThan(mid),
      reason: 'zoom accumulates across the gesture (not pinned to start)',
    );
  });

  testWidgets('trackpad two-finger scroll down zooms out', (tester) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(center);
    await tester.pump();
    await gesture.panZoomUpdate(center, pan: const Offset(0, 100));
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, lessThan(start));
  });

  testWidgets('trackpad pinch out zooms in', (tester) async {
    final controller = await pumpMap(tester);
    final start = controller.camera.zoom;
    final center = tester.getCenter(find.byType(FlutterMap));

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(center);
    await tester.pump();
    await gesture.panZoomUpdate(center, scale: 2.0);
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, greaterThan(start));
  });
}
