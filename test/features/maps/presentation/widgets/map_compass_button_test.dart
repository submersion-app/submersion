import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';

import '../../../../helpers/test_app.dart';

void main() {
  Future<MapController> pumpCompass(WidgetTester tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      // Pinned to English so the tooltip finder is deterministic.
      testApp(
        locale: const Locale('en'),
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 5,
              ),
              children: const [],
            ),
            Positioned(
              top: 16,
              right: 16,
              child: MapCompassButton(controller: controller),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  // Scope to the compass: FlutterMap has its own AnimatedOpacity/IgnorePointer.
  final compassOpacity = find.descendant(
    of: find.byType(MapCompassButton),
    matching: find.byType(AnimatedOpacity),
  );
  final compassIgnorePointer = find.descendant(
    of: find.byType(MapCompassButton),
    matching: find.byType(IgnorePointer),
  );

  double opacity(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(compassOpacity).opacity;

  bool ignoring(WidgetTester tester) =>
      tester.widget<IgnorePointer>(compassIgnorePointer).ignoring;

  testWidgets('is hidden while the map is north-up', (tester) async {
    await pumpCompass(tester);

    expect(opacity(tester), 0, reason: 'no affordance needed at 0 degrees');
    // Hidden control must not steal taps meant for the map beneath it.
    expect(ignoring(tester), isTrue);
  });

  testWidgets('fades in once the map is rotated', (tester) async {
    final controller = await pumpCompass(tester);

    controller.rotate(45);
    await tester.pump();

    expect(opacity(tester), 1);
    expect(ignoring(tester), isFalse);
  });

  testWidgets('tapping resets the map back to north and hides again', (
    tester,
  ) async {
    final controller = await pumpCompass(tester);

    controller.rotate(45);
    await tester.pump();
    expect(controller.camera.rotation, 45);

    await tester.tap(find.byTooltip('North up'));
    await tester.pumpAndSettle();

    expect(controller.camera.rotation.abs() % 360, closeTo(0, 0.01));
    expect(opacity(tester), 0);
  });

  testWidgets('near-360 rotation glides forward to north, not back through 0', (
    tester,
  ) async {
    final controller = await pumpCompass(tester);

    // 350 degrees is only 10 degrees short of a full turn; resetting should
    // climb forward toward 360 rather than unwinding ~350 degrees back to 0.
    controller.rotate(350);
    await tester.pump();

    await tester.tap(find.byTooltip('North up'));
    // Sample mid-glide: the shortest path forward keeps the bearing at/above
    // the 350 start; unwinding to 0 would instead drop it below 350.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.camera.rotation, greaterThanOrEqualTo(350));

    await tester.pumpAndSettle();

    // End state is north-up regardless of whether the controller keeps 360 or
    // normalizes it to 0.
    expect(controller.camera.rotation % 360, closeTo(0, 0.01));
    expect(opacity(tester), 0);
  });

  testWidgets('disposing mid-reset does not throw', (tester) async {
    final controller = await pumpCompass(tester);

    controller.rotate(90);
    await tester.pump();

    await tester.tap(find.byTooltip('North up'));
    await tester.pump(); // start the glide-to-north animation
    await tester.pump(const Duration(milliseconds: 100)); // partway through

    // Tear the compass out of the tree while the animation is still running,
    // cancelling the ticker mid-flight.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
