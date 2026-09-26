import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';

Future<MapController> _pumpMap(WidgetTester tester) async {
  final controller = MapController();
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: FlutterMap(
          mapController: controller,
          options: const MapOptions(
            initialCenter: LatLng(0, 0),
            initialZoom: 2,
          ),
          children: const [],
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('animateTo lands on the target at zoom 12 from a wide view', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    final done = animator.animateTo(const LatLng(10, 20));
    await tester.pumpAndSettle();
    await done;

    expect(controller.camera.center.latitude, closeTo(10, 1e-6));
    expect(controller.camera.center.longitude, closeTo(20, 1e-6));
    expect(controller.camera.zoom, closeTo(12, 1e-6));
  });

  testWidgets('animateTo keeps the zoom when already at 10 or closer', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    controller.move(const LatLng(0, 0), 14);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    final done = animator.animateTo(const LatLng(1, 1));
    await tester.pumpAndSettle();
    await done;

    expect(controller.camera.zoom, closeTo(14, 1e-6));
  });

  testWidgets('animateToBounds ends inside the bounds and at most zoom 14', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    final done = animator.animateToBounds(
      LatLngBounds(const LatLng(10, 10), const LatLng(10.01, 10.01)),
    );
    await tester.pumpAndSettle();
    await done;

    expect(controller.camera.center.latitude, closeTo(10.005, 1e-3));
    expect(controller.camera.zoom, lessThanOrEqualTo(14));
  });

  testWidgets('fitAll with one point moves to zoom 12', (tester) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    animator.fitAll([const LatLng(-8, 115)]);
    await tester.pump();

    expect(controller.camera.center.latitude, closeTo(-8, 1e-6));
    expect(controller.camera.zoom, closeTo(12, 1e-6));
  });

  testWidgets('fitAll with an empty list leaves the camera alone', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    animator.fitAll(const []);
    await tester.pump();

    expect(controller.camera.zoom, closeTo(2, 1e-6));
  });

  testWidgets(
    'dispose mid-flight completes the pending future without throwing',
    (tester) async {
      final controller = await _pumpMap(tester);
      final animator = MapCameraAnimator(
        controller: controller,
        vsync: const TestVSync(),
      );

      final done = animator.animateTo(const LatLng(10, 20));
      await tester.pump(const Duration(milliseconds: 100));
      animator.dispose();
      await tester.pumpAndSettle();

      await done.timeout(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      // The camera stopped short of the target: the flight was cancelled.
      expect(controller.camera.center.latitude, lessThan(10));
    },
  );

  testWidgets('fitAll with a single unusable point leaves the camera alone', (
    tester,
  ) async {
    final controller = await _pumpMap(tester);
    final animator = MapCameraAnimator(
      controller: controller,
      vsync: const TestVSync(),
    );
    addTearDown(animator.dispose);

    animator.fitAll([const LatLng(95, 200)]);
    animator.fitAll([const LatLng(double.nan, 0)]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.camera.zoom, closeTo(2, 1e-6));
  });

  testWidgets(
    'fitAll cancels an in-flight move so it cannot overwrite the fit',
    (tester) async {
      final controller = await _pumpMap(tester);
      final animator = MapCameraAnimator(
        controller: controller,
        vsync: const TestVSync(),
      );
      addTearDown(animator.dispose);

      final done = animator.animateToBounds(
        LatLngBounds(const LatLng(10, 10), const LatLng(10.01, 10.01)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      animator.fitAll([const LatLng(-8, 115)]);
      await tester.pumpAndSettle();
      await done.timeout(const Duration(seconds: 1));

      expect(controller.camera.center.latitude, closeTo(-8, 1e-6));
      expect(controller.camera.zoom, closeTo(12, 1e-6));
    },
  );
}
