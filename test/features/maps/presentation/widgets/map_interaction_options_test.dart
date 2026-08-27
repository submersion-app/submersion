import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';

/// A point along a two-finger gesture: how far apart the fingers have spread
/// relative to where they started, and how far the line between them has
/// twisted, both measured from the start of the gesture.
typedef _Waypoint = ({double scale, double twistDegrees});

void main() {
  Future<MapController> pumpMap(
    WidgetTester tester,
    InteractionOptions interactionOptions,
  ) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: const LatLng(0, 0),
                  initialZoom: 5,
                  minZoom: 1,
                  maxZoom: 18,
                  interactionOptions: interactionOptions,
                ),
                children: const [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  /// Interpolates a straight run of waypoints, so a gesture grows the way a
  /// real hand does instead of teleporting to its end state in one update.
  List<_Waypoint> ramp({
    required double toScale,
    required double toTwist,
    double fromScale = 1.0,
    double fromTwist = 0.0,
    int steps = 10,
  }) => [
    for (var step = 1; step <= steps; step++)
      (
        scale: fromScale + (toScale - fromScale) * step / steps,
        twistDegrees: fromTwist + (toTwist - fromTwist) * step / steps,
      ),
  ];

  /// Drives one continuous two-finger gesture through [waypoints]. The fingers
  /// stay symmetric about [center], so the focal point never moves and only
  /// the scale and twist under test can win the gesture race.
  Future<void> twoFingerGesture(
    WidgetTester tester,
    Offset center,
    List<_Waypoint> waypoints,
  ) async {
    const startRadius = 60.0;
    // Flutter derives ScaleUpdateDetails.rotation from atan2 of the line
    // between the pointers, which is discontinuous at +/- pi. Starting the
    // fingers on the vertical axis rather than the horizontal one keeps the
    // measurement away from that branch cut, so a 10 degree twist reads as 10
    // degrees instead of wrapping to -350.
    const startAngleDegrees = 90.0;

    Offset fingerOffset(_Waypoint waypoint) {
      final radians =
          (startAngleDegrees + waypoint.twistDegrees) * math.pi / 180;
      final radius = startRadius * waypoint.scale;
      return Offset(radius * math.cos(radians), radius * math.sin(radians));
    }

    final start = fingerOffset((scale: 1.0, twistDegrees: 0.0));
    final first = await tester.startGesture(center - start, pointer: 1);
    final second = await tester.startGesture(center + start, pointer: 2);
    await tester.pump();

    for (final waypoint in waypoints) {
      final offset = fingerOffset(waypoint);
      await first.moveTo(center - offset);
      await second.moveTo(center + offset);
      await tester.pump();
    }

    await first.up();
    await second.up();
    await tester.pump();
  }

  Offset mapCenter(WidgetTester tester) =>
      tester.getCenter(find.byType(FlutterMap));

  testWidgets('flutter_map defaults rotate on any twist while pinching', (
    tester,
  ) async {
    // Characterizes the upstream behaviour rotatableMapInteraction exists to
    // correct (issue #1067): InteractionOptions ships rotationThreshold: 20
    // but enableMultiFingerGestureRace: false, and with the race off that
    // threshold is never consulted, so a 10 degree wobble rotates the map.
    // This also proves the gesture below is capable of rotating a map, so the
    // next test cannot pass for the wrong reason.
    final controller = await pumpMap(tester, const InteractionOptions());

    await twoFingerGesture(
      tester,
      mapCenter(tester),
      ramp(toScale: 2.0, toTwist: 10),
    );

    expect(controller.camera.rotation.abs(), greaterThan(1.0));
  });

  group('rotatableMapInteraction', () {
    testWidgets('a pinch with an incidental twist does not rotate the map', (
      tester,
    ) async {
      final controller = await pumpMap(tester, rotatableMapInteraction);
      final startZoom = controller.camera.zoom;

      await twoFingerGesture(
        tester,
        mapCenter(tester),
        ramp(toScale: 2.0, toTwist: 10),
      );

      expect(controller.camera.rotation, 0.0);
      expect(controller.camera.zoom, greaterThan(startZoom));
    });

    testWidgets('a deliberate twist past the threshold rotates the map', (
      tester,
    ) async {
      final controller = await pumpMap(tester, rotatableMapInteraction);

      await twoFingerGesture(
        tester,
        mapCenter(tester),
        ramp(toScale: 1.0, toTwist: 45),
      );

      expect(controller.camera.rotation.abs(), greaterThan(1.0));
    });

    testWidgets('zooming still works after a twist has won the gesture', (
      tester,
    ) async {
      // Rotation deliberately hands the rest of the gesture back to zoom and
      // pan: once the twist is intentional, spreading the same two fingers
      // should still zoom. Only the reverse order is blocked.
      final controller = await pumpMap(tester, rotatableMapInteraction);
      final startZoom = controller.camera.zoom;

      await twoFingerGesture(tester, mapCenter(tester), [
        ...ramp(toScale: 1.0, toTwist: 45),
        ...ramp(fromScale: 1.0, fromTwist: 45, toScale: 1.8, toTwist: 45),
      ]);

      expect(controller.camera.rotation.abs(), greaterThan(1.0));
      expect(controller.camera.zoom, greaterThan(startZoom));
    });
  });
}
