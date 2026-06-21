import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('mapInteractionOptions', () {
    test('touch enables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: true, allowRotation: false);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isTrue);
      expect(InteractiveFlag.hasPinchMove(o.flags), isTrue);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isTrue);
    });

    test('non-touch disables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: false, allowRotation: true);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isFalse);
      expect(InteractiveFlag.hasPinchMove(o.flags), isFalse);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isFalse);
    });

    test('rotate gesture only for touch with rotation allowed', () {
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: true, allowRotation: true).flags,
        ),
        isTrue,
      );
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: true, allowRotation: false).flags,
        ),
        isFalse,
      );
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: false, allowRotation: true).flags,
        ),
        isFalse,
      );
    });

    test('gesture race enabled only when rotating by touch', () {
      expect(
        mapInteractionOptions(
          isTouch: true,
          allowRotation: true,
        ).enableMultiFingerGestureRace,
        isTrue,
      );
      expect(
        mapInteractionOptions(
          isTouch: false,
          allowRotation: true,
        ).enableMultiFingerGestureRace,
        isFalse,
      );
    });

    test('rotation threshold widened to 30 degrees', () {
      expect(
        mapInteractionOptions(
          isTouch: true,
          allowRotation: true,
        ).rotationThreshold,
        30.0,
      );
    });

    test('scroll-wheel zoom and drag always enabled', () {
      for (final isTouch in [true, false]) {
        for (final allowRotation in [true, false]) {
          final o = mapInteractionOptions(
            isTouch: isTouch,
            allowRotation: allowRotation,
          );
          expect(InteractiveFlag.hasScrollWheelZoom(o.flags), isTrue);
          expect(InteractiveFlag.hasDrag(o.flags), isTrue);
        }
      }
    });
  });

  group('MapResetNorthButton', () {
    Widget harness(MapController controller) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: FlutterMap(
            mapController: controller,
            options: const MapOptions(
              initialCenter: LatLng(0, 0),
              initialZoom: 3,
            ),
            children: const [MapResetNorthButton()],
          ),
        ),
      ),
    );

    testWidgets('hidden at north, shown when rotated, resets on tap', (
      tester,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(harness(controller));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      controller.rotate(45);
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(controller.camera.rotation.abs() < 0.01, isTrue);
      expect(find.byType(FloatingActionButton), findsNothing);
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
              allowRotation: true,
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
    testWidgets('pinch zooms in and keeps the anchor point fixed', (
      tester,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: MapInteractionDetector(
                allowRotation: false,
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
        ),
      );
      await tester.pump();

      // Force the detector into its non-touch (desktop) state so flutter_map's
      // native pinch is disabled and only our trackpad handler can move the map.
      final mouse = TestPointer(2, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.addPointer(location: const Offset(5, 5)),
      );
      await tester.sendEventToBinding(mouse.hover(const Offset(5, 5)));
      await tester.pump();

      const anchor = Offset(300, 120); // off-center
      final latLngUnderAnchorBefore = controller.camera.offsetToCrs(anchor);
      final zoomBefore = controller.camera.zoom;

      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(anchor));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(anchor, scale: 2.0),
      );
      await tester.pump();
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      expect(controller.camera.zoom, greaterThan(zoomBefore));
      final latLngUnderAnchorAfter = controller.camera.offsetToCrs(anchor);
      expect(
        (latLngUnderAnchorAfter.latitude - latLngUnderAnchorBefore.latitude)
            .abs(),
        lessThan(0.5),
      );
      expect(
        (latLngUnderAnchorAfter.longitude - latLngUnderAnchorBefore.longitude)
            .abs(),
        lessThan(0.5),
      );
    });

    testWidgets('vertical pan moves the camera center along latitude', (
      tester,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: MapInteractionDetector(
                allowRotation: false,
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
        ),
      );
      await tester.pump();

      // Force the detector into its non-touch (desktop) state so flutter_map's
      // native pinch is disabled and only our trackpad handler can move the map.
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

      // Latitude should have shifted by a non-trivial amount.
      expect(
        (controller.camera.center.latitude - latBefore).abs(),
        greaterThan(0.0001),
      );
      // Zoom should be essentially unchanged (scale was 1.0).
      expect((controller.camera.zoom - zoomBefore).abs(), lessThan(0.01));
    });
  });

  group('MapInteractionDetector trackpad pan with map rotation', () {
    testWidgets(
      'pan on rotated map calls _rotateOffset with non-zero radians',
      (tester) async {
        final controller = MapController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapInteractionDetector(
                  allowRotation: true,
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
          ),
        );
        await tester.pump();

        // Force non-touch (desktop) mode so our trackpad handler runs.
        final mouse = TestPointer(2, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          mouse.addPointer(location: const Offset(5, 5)),
        );
        await tester.sendEventToBinding(mouse.hover(const Offset(5, 5)));
        await tester.pump();

        // Rotate the map to a non-zero bearing so _rotateOffset receives
        // non-zero radians when computing the panned offset.
        controller.rotate(45);
        await tester.pump();

        final latBefore = controller.camera.center.latitude;

        // Trackpad pan while map is rotated -> exercises the cos/sin path.
        const panOrigin = Offset(200, 200);
        final pointer = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pointer.panZoomStart(panOrigin));
        await tester.sendEventToBinding(
          pointer.panZoomUpdate(
            panOrigin,
            scale: 1.0,
            pan: const Offset(0, 80),
          ),
        );
        await tester.pump();
        await tester.sendEventToBinding(pointer.panZoomEnd());
        await tester.pump();

        // Camera should have moved.
        expect(
          (controller.camera.center.latitude - latBefore).abs(),
          greaterThan(0.0001),
        );
      },
    );
  });

  group('MapInteractionDetector _defaultIsTouch platform branches', () {
    // The _defaultIsTouch() method is called in initState.
    // Touch platforms (iOS, Android) default to isTouch=true -> pinchZoom enabled.
    // Desktop platforms (macOS, windows, linux, fuchsia) default to isTouch=false.
    //
    // debugDefaultTargetPlatformOverride must be cleared synchronously at the
    // end of the test body because the Flutter test framework checks all debug
    // vars are unset before running addTearDown callbacks.

    Widget _detectorWidget(void Function(InteractionOptions) capture) =>
        MaterialApp(
          home: Scaffold(
            body: MapInteractionDetector(
              allowRotation: false,
              mapController: MapController(),
              builder: (context, options) {
                capture(options);
                return const SizedBox(width: 400, height: 400);
              },
            ),
          ),
        );

    testWidgets('iOS defaults to touch (pinchZoom enabled)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late InteractionOptions latest;
      await tester.pumpWidget(_detectorWidget((o) => latest = o));
      await tester.pump();
      final result = InteractiveFlag.hasPinchZoom(latest.flags);
      debugDefaultTargetPlatformOverride = null;
      expect(result, isTrue);
    });

    testWidgets('android defaults to touch (pinchZoom enabled)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      late InteractionOptions latest;
      await tester.pumpWidget(_detectorWidget((o) => latest = o));
      await tester.pump();
      final result = InteractiveFlag.hasPinchZoom(latest.flags);
      debugDefaultTargetPlatformOverride = null;
      expect(result, isTrue);
    });

    testWidgets('macOS defaults to non-touch (pinchZoom disabled)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      late InteractionOptions latest;
      await tester.pumpWidget(_detectorWidget((o) => latest = o));
      await tester.pump();
      final result = InteractiveFlag.hasPinchZoom(latest.flags);
      debugDefaultTargetPlatformOverride = null;
      expect(result, isFalse);
    });

    testWidgets('windows defaults to non-touch (pinchZoom disabled)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      late InteractionOptions latest;
      await tester.pumpWidget(_detectorWidget((o) => latest = o));
      await tester.pump();
      final result = InteractiveFlag.hasPinchZoom(latest.flags);
      debugDefaultTargetPlatformOverride = null;
      expect(result, isFalse);
    });

    testWidgets('linux defaults to non-touch (pinchZoom disabled)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      late InteractionOptions latest;
      await tester.pumpWidget(_detectorWidget((o) => latest = o));
      await tester.pump();
      final result = InteractiveFlag.hasPinchZoom(latest.flags);
      debugDefaultTargetPlatformOverride = null;
      expect(result, isFalse);
    });

    testWidgets('fuchsia defaults to non-touch (pinchZoom disabled)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      late InteractionOptions latest;
      await tester.pumpWidget(_detectorWidget((o) => latest = o));
      await tester.pump();
      final result = InteractiveFlag.hasPinchZoom(latest.flags);
      debugDefaultTargetPlatformOverride = null;
      expect(result, isFalse);
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
              allowRotation: true,
              mapController: controller,
              builder: (context, options) {
                latest = options;
                return const SizedBox(width: 400, height: 400);
              },
            ),
          ),
        ),
      );

      // First touch pointer down -> isTouch=true, pinchZoom enabled
      final touch1 = TestPointer(1, PointerDeviceKind.touch);
      await tester.sendEventToBinding(
        touch1.addPointer(location: const Offset(200, 200)),
      );
      await tester.sendEventToBinding(touch1.down(const Offset(200, 200)));
      await tester.pump();
      expect(InteractiveFlag.hasPinchZoom(latest.flags), isTrue);

      // Second touch pointer down (same kind) -> _setTouch(true) when already true,
      // guard `if (_isTouch != value)` prevents setState -> state unchanged
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

  group('shouldShowResetNorth', () {
    test('hidden at or near north', () {
      expect(shouldShowResetNorth(0), isFalse);
      expect(shouldShowResetNorth(0.3), isFalse);
      expect(shouldShowResetNorth(359.8), isFalse);
      expect(shouldShowResetNorth(360), isFalse);
    });

    test('shown when meaningfully rotated', () {
      expect(shouldShowResetNorth(15), isTrue);
      expect(shouldShowResetNorth(90), isTrue);
      expect(shouldShowResetNorth(200), isTrue);
      expect(shouldShowResetNorth(-15), isTrue);
    });
  });
}
