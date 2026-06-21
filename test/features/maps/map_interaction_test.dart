import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';

void main() {
  group('mapInteractionOptions', () {
    test('touch enables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: true);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isTrue);
      expect(InteractiveFlag.hasPinchMove(o.flags), isTrue);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isTrue);
    });

    test('non-touch disables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: false);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isFalse);
      expect(InteractiveFlag.hasPinchMove(o.flags), isFalse);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isFalse);
    });

    test('rotation is never enabled (gesture or cursor/keyboard)', () {
      for (final isTouch in [true, false]) {
        final o = mapInteractionOptions(isTouch: isTouch);
        expect(InteractiveFlag.hasRotate(o.flags), isFalse);
        // CursorKeyboardRotationOptions.disabled() sets isKeyTrigger to a
        // function that always returns false (Ctrl+drag rotation off).
        expect(o.cursorKeyboardRotationOptions.isKeyTrigger, isNotNull);
      }
    });

    test('scroll-wheel zoom and drag always enabled', () {
      for (final isTouch in [true, false]) {
        final o = mapInteractionOptions(isTouch: isTouch);
        expect(InteractiveFlag.hasScrollWheelZoom(o.flags), isTrue);
        expect(InteractiveFlag.hasDrag(o.flags), isTrue);
      }
    });
  });

  group('MapInteractionDetector pointer kind', () {
    testWidgets('flags reflect touch vs mouse pointer', (tester) async {
      late InteractionOptions latest;
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapInteractionDetector(
              mapController: controller,
              builder: (context, options) {
                latest = options;
                return const SizedBox(width: 400, height: 400);
              },
            ),
          ),
        ),
      );

      // Touch down -> pinch zoom enabled.
      final touchPointer = TestPointer(1, PointerDeviceKind.touch);
      await tester.sendEventToBinding(
        touchPointer.addPointer(location: const Offset(200, 200)),
      );
      await tester.sendEventToBinding(
        touchPointer.down(const Offset(200, 200)),
      );
      await tester.pump();
      expect(InteractiveFlag.hasPinchZoom(latest.flags), isTrue);
      await tester.sendEventToBinding(touchPointer.up());
      await tester.pump();

      // Mouse hover -> pinch zoom disabled (trackpad/mouse path).
      final mousePointer = TestPointer(2, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mousePointer.addPointer(location: const Offset(200, 200)),
      );
      await tester.sendEventToBinding(
        mousePointer.hover(const Offset(210, 210)),
      );
      await tester.pump();
      expect(InteractiveFlag.hasPinchZoom(latest.flags), isFalse);
      await tester.sendEventToBinding(mousePointer.removePointer());
    });
  });

  group('MapInteractionDetector trackpad zoom', () {
    Widget harness(MapController controller) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: MapInteractionDetector(
            mapController: controller,
            builder: (context, options) => FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: const LatLng(0, 0),
                initialZoom: 3,
                interactionOptions: options,
              ),
              children: const [],
            ),
          ),
        ),
      ),
    );

    testWidgets(
      'pinch anchors zoom at the last hover position, not the gesture position',
      (tester) async {
        final controller = MapController();
        await tester.pumpWidget(harness(controller));
        await tester.pump();

        // Hover at an off-center point so the detector records it as the
        // reliable cursor position (this also flips the detector to non-touch
        // so flutter_map's native pinch is disabled).
        const hoverPoint = Offset(300, 120);
        final mouse = TestPointer(2, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.addPointer(location: hoverPoint));
        await tester.sendEventToBinding(mouse.hover(hoverPoint));
        await tester.pump();

        final latLngUnderHoverBefore = controller.camera.offsetToCrs(
          hoverPoint,
        );
        final zoomBefore = controller.camera.zoom;

        // Trackpad pinch whose event position is BOGUS (deliberately different
        // from the cursor), mimicking macOS where PointerPanZoom localPosition
        // is unreliable (flutter/flutter#136029). The zoom must still anchor at
        // the hover point, NOT the bogus gesture position.
        const bogus = Offset(40, 380);
        final pad = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pad.panZoomStart(bogus));
        await tester.sendEventToBinding(pad.panZoomUpdate(bogus, scale: 2.0));
        await tester.pump();
        await tester.sendEventToBinding(pad.panZoomEnd());
        await tester.pump();

        expect(controller.camera.zoom, greaterThan(zoomBefore));
        final latLngUnderHoverAfter = controller.camera.offsetToCrs(hoverPoint);
        expect(
          (latLngUnderHoverAfter.latitude - latLngUnderHoverBefore.latitude)
              .abs(),
          lessThan(0.5),
        );
        expect(
          (latLngUnderHoverAfter.longitude - latLngUnderHoverBefore.longitude)
              .abs(),
          lessThan(0.5),
        );
      },
    );

    testWidgets('vertical pan moves the camera center along latitude', (
      tester,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(harness(controller));
      await tester.pump();

      // Force the detector into its non-touch (desktop) state.
      final mouse = TestPointer(2, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.addPointer(location: const Offset(5, 5)),
      );
      await tester.sendEventToBinding(mouse.hover(const Offset(5, 5)));
      await tester.pump();

      const panOrigin = Offset(200, 200);
      final latBefore = controller.camera.center.latitude;
      final zoomBefore = controller.camera.zoom;

      // Pure vertical pan (scale: 1.0 -> no zoom change).
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(panOrigin));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(panOrigin, scale: 1.0, pan: const Offset(0, 60)),
      );
      await tester.pump();
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      expect(
        (controller.camera.center.latitude - latBefore).abs(),
        greaterThan(0.0001),
      );
      expect((controller.camera.zoom - zoomBefore).abs(), lessThan(0.01));
    });

    testWidgets('pan on a rotated camera still moves the center', (
      tester,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(harness(controller));
      await tester.pump();

      final mouse = TestPointer(2, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.addPointer(location: const Offset(5, 5)),
      );
      await tester.sendEventToBinding(mouse.hover(const Offset(5, 5)));
      await tester.pump();

      // Programmatic rotation still works (only gesture rotation is disabled);
      // this exercises _rotateOffset with non-zero radians.
      controller.rotate(45);
      await tester.pump();

      final latBefore = controller.camera.center.latitude;
      const panOrigin = Offset(200, 200);
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(panOrigin));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(panOrigin, scale: 1.0, pan: const Offset(0, 80)),
      );
      await tester.pump();
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      expect(
        (controller.camera.center.latitude - latBefore).abs(),
        greaterThan(0.0001),
      );
    });
  });

  group('MapInteractionDetector _defaultIsTouch platform branches', () {
    // debugDefaultTargetPlatformOverride must be cleared synchronously at the
    // end of the test body (the test framework checks debug vars are unset
    // before running addTearDown callbacks).
    Widget detectorWidget(void Function(InteractionOptions) capture) =>
        MaterialApp(
          home: Scaffold(
            body: MapInteractionDetector(
              mapController: MapController(),
              builder: (context, options) {
                capture(options);
                return const SizedBox(width: 400, height: 400);
              },
            ),
          ),
        );

    Future<bool> pinchZoomFor(WidgetTester tester, TargetPlatform p) async {
      debugDefaultTargetPlatformOverride = p;
      late InteractionOptions latest;
      await tester.pumpWidget(detectorWidget((o) => latest = o));
      await tester.pump();
      final result = InteractiveFlag.hasPinchZoom(latest.flags);
      debugDefaultTargetPlatformOverride = null;
      return result;
    }

    testWidgets('iOS / android default to touch (pinchZoom enabled)', (
      tester,
    ) async {
      expect(await pinchZoomFor(tester, TargetPlatform.iOS), isTrue);
      expect(await pinchZoomFor(tester, TargetPlatform.android), isTrue);
    });

    testWidgets('desktop platforms default to non-touch (pinchZoom disabled)', (
      tester,
    ) async {
      expect(await pinchZoomFor(tester, TargetPlatform.macOS), isFalse);
      expect(await pinchZoomFor(tester, TargetPlatform.windows), isFalse);
      expect(await pinchZoomFor(tester, TargetPlatform.linux), isFalse);
      expect(await pinchZoomFor(tester, TargetPlatform.fuchsia), isFalse);
    });
  });

  group('MapInteractionDetector _setTouch no-op guard', () {
    testWidgets('second touch event with same kind does not change state', (
      tester,
    ) async {
      late InteractionOptions latest;
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapInteractionDetector(
              mapController: controller,
              builder: (context, options) {
                latest = options;
                return const SizedBox(width: 400, height: 400);
              },
            ),
          ),
        ),
      );

      final touch1 = TestPointer(1, PointerDeviceKind.touch);
      await tester.sendEventToBinding(
        touch1.addPointer(location: const Offset(200, 200)),
      );
      await tester.sendEventToBinding(touch1.down(const Offset(200, 200)));
      await tester.pump();
      expect(InteractiveFlag.hasPinchZoom(latest.flags), isTrue);

      // Second touch (same kind) -> _setTouch(true) when already true; the
      // guard prevents a redundant setState. State stays touch.
      final touch2 = TestPointer(2, PointerDeviceKind.touch);
      await tester.sendEventToBinding(
        touch2.addPointer(location: const Offset(210, 210)),
      );
      await tester.sendEventToBinding(touch2.down(const Offset(210, 210)));
      await tester.pump();
      expect(InteractiveFlag.hasPinchZoom(latest.flags), isTrue);

      await tester.sendEventToBinding(touch1.up());
      await tester.sendEventToBinding(touch2.up());
      await tester.pump();
    });
  });
}
