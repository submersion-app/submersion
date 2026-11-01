import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_scale_handle_layer.dart';

import '../../../../helpers/test_app.dart';

const _pivot = GeoPoint(28.5722, 34.5372);
const _handle = ValueKey('nav-track-align-scale-handle');

/// A map with the handle 80 m north of the pivot at 100%, moved by the scale
/// the way the alignment page moves it.
class _Host extends StatefulWidget {
  const _Host({this.rotationDeg = 0});

  final double rotationDeg;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final mapKey = GlobalKey();
  final controller = MapController();
  double scale = 1;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: mapKey,
    width: 600,
    height: 500,
    child: FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: LatLng(_pivot.latitude, _pivot.longitude),
        initialZoom: 18,
        initialRotation: widget.rotationDeg,
      ),
      children: [
        NavTrackScaleHandleLayer(
          mapKey: mapKey,
          point: offsetToGeoPoint(_pivot, east: 0, north: 80 * scale),
          pivot: _pivot,
          scaleFactor: scale,
          onChanged: (value) => setState(() => scale = value),
        ),
      ],
    ),
  );
}

void main() {
  Future<_HostState> pump(WidgetTester tester, {double rotationDeg = 0}) async {
    await tester.pumpWidget(
      testApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: _Host(rotationDeg: rotationDeg),
        ),
      ),
    );
    await tester.pump();
    return tester.state<_HostState>(find.byType(_Host));
  }

  /// Presses the handle and moves in steps to [to], a global position.
  Future<TestGesture> dragTo(WidgetTester tester, Offset to) async {
    final from = tester.getCenter(find.byKey(_handle));
    final gesture = await tester.startGesture(from);
    await tester.pump();
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
      await tester.pump();
    }
    return gesture;
  }

  /// Where [point] is on screen, as a global position.
  Offset globalOf(_HostState host, WidgetTester tester, GeoPoint point) {
    final topLeft = tester.getTopLeft(find.byKey(host.mapKey));
    return topLeft +
        host.controller.camera.latLngToScreenOffset(
          LatLng(point.latitude, point.longitude),
        );
  }

  testWidgets('dragging away from the pivot grows the scale', (tester) async {
    final host = await pump(tester);
    final from = tester.getCenter(find.byKey(_handle));
    final gesture = await dragTo(tester, from + const Offset(0, -60));
    await gesture.up();
    await tester.pump();
    expect(host.scale, greaterThan(1.2));
  });

  testWidgets('dragging toward the pivot shrinks the scale', (tester) async {
    final host = await pump(tester);
    final from = tester.getCenter(find.byKey(_handle));
    final gesture = await dragTo(tester, from + const Offset(0, 60));
    await gesture.up();
    await tester.pump();
    expect(host.scale, lessThan(0.8));
  });

  testWidgets('a sideways move at constant distance leaves the scale alone', (
    tester,
  ) async {
    final host = await pump(tester);
    final center = globalOf(host, tester, _pivot);
    final from = tester.getCenter(find.byKey(_handle));
    final vector = from - center;
    final gesture = await tester.startGesture(from);
    await tester.pump();
    // Round the arc, so the pointer never leaves the handle's circle.
    for (var i = 1; i <= 12; i++) {
      final angle = i * math.pi / 2 / 12;
      await gesture.moveTo(
        center +
            Offset(
              vector.dx * math.cos(angle) - vector.dy * math.sin(angle),
              vector.dx * math.sin(angle) + vector.dy * math.cos(angle),
            ),
      );
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    expect(host.scale, closeTo(1, 0.01));
  });

  testWidgets('a drag does not pan the map', (tester) async {
    final host = await pump(tester);
    final before = host.controller.camera.center;
    final from = tester.getCenter(find.byKey(_handle));
    final gesture = await dragTo(tester, from + const Offset(0, -80));
    await gesture.up();
    await tester.pump();
    expect(host.controller.camera.center, before);
  });

  testWidgets('the handle stays under the pointer', (tester) async {
    await pump(tester);
    final from = tester.getCenter(find.byKey(_handle));
    final to = from + const Offset(0, -70);
    final gesture = await dragTo(tester, to);
    expect((tester.getCenter(find.byKey(_handle)) - to).distance, lessThan(1));
    await gesture.up();
  });

  testWidgets('the handle tracks the pointer on a rotated map', (tester) async {
    final host = await pump(tester, rotationDeg: 90);
    final center = globalOf(host, tester, _pivot);
    final from = tester.getCenter(find.byKey(_handle));
    // North is not up here, so "away from the pivot" is whatever the screen
    // says it is: out along the line from the pivot to the handle.
    final to = center + (from - center) * 1.5;
    final gesture = await dragTo(tester, to);
    expect(host.scale, closeTo(1.5, 0.01));
    expect((tester.getCenter(find.byKey(_handle)) - to).distance, lessThan(1));
    await gesture.up();
  });

  testWidgets('dragging through the pivot clamps instead of flipping', (
    tester,
  ) async {
    final host = await pump(tester);
    final center = globalOf(host, tester, _pivot);
    final gesture = await dragTo(tester, center);
    expect(host.scale, 0.25);
    await gesture.up();
  });

  testWidgets('offers a label for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel('Drag to resize the track'), findsOneWidget);
    semantics.dispose();
  });
}
