import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';

const _mapKey = ValueKey('heat-map');

Future<void> _pumpHeatMap(
  WidgetTester tester, {
  required LatLng center,
  required List<HeatMapPoint> points,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: _mapKey,
            child: SizedBox(
              width: 800,
              height: 600,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 3,
                  cameraConstraint: const CameraConstraint.containLatitude(),
                ),
                children: [
                  HeatMapLayer(points: points, radius: 30, opacity: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // The fragment program loads asynchronously; let it resolve for real.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

/// The RGBA colour of the rendered map at [x], [y] in logical pixels.
Future<int> _pixelAt(WidgetTester tester, double x, double y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_mapKey),
  );
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data;
  }))!;
  return bytes.getUint32(((y.round() * 800) + x.round()) * 4);
}

/// Whether heat was painted at [x], [y]: its colour differs from the empty
/// map background, sampled in a corner far from every point.
Future<bool> _heatAt(WidgetTester tester, double x, double y) async =>
    await _pixelAt(tester, x, y) != await _pixelAt(tester, 2, 598);

void main() {
  testWidgets('paints a heat blob at the point', (tester) async {
    await _pumpHeatMap(
      tester,
      center: const LatLng(0, 0),
      points: const [HeatMapPoint(location: LatLng(0, 0), weight: 1)],
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(await _heatAt(tester, 400, 300), isTrue);
    expect(await _heatAt(tester, 20, 20), isFalse);
  });

  testWidgets('paints a point from across the date line east of centre', (
    tester,
  ) async {
    // Centred on 175E; the point at 170W is 15 degrees east, in the copy of
    // the world past 180. At zoom 3 the world is 2048 px wide.
    await _pumpHeatMap(
      tester,
      center: const LatLng(0, 175),
      points: const [HeatMapPoint(location: LatLng(0, -170), weight: 1)],
    );

    const x = 400 + 2048 * 15 / 360;
    expect(await _heatAt(tester, x, 300), isTrue);
    // Without the repeat it would land 2048 px to the left, off screen, and
    // nothing would be painted.
    expect(await _heatAt(tester, 400, 300), isFalse);
  });

  testWidgets('paints the edge of a blob from a world just off screen', (
    tester,
  ) async {
    // At zoom 3 a degree is 2048 / 360 px. Centred so the right edge sits at
    // 179.5E, the copy of the world past 180 is entirely off screen, but a
    // point at 179.5W is only one degree (about 6 px) past the edge, well
    // inside the 30 px blob radius.
    const degreesToEdge = 400 / (2048 / 360);
    await _pumpHeatMap(
      tester,
      center: const LatLng(0, 179.5 - degreesToEdge),
      points: const [HeatMapPoint(location: LatLng(0, -179.5), weight: 1)],
    );

    expect(await _heatAt(tester, 799, 300), isTrue);
  });
}
