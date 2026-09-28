import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';

MapCamera _camera({
  required double longitude,
  double zoom = 3,
  Crs crs = const Epsg3857(),
  Size size = const Size(800, 600),
}) => MapCamera(
  crs: crs,
  center: LatLng(0, longitude),
  zoom: zoom,
  rotation: 0,
  nonRotatedSize: size,
);

void main() {
  group('worldCopyCameras', () {
    test('is just the camera when the view sits inside one world', () {
      final camera = _camera(longitude: 0, zoom: 5);
      final copies = worldCopyCameras(camera);

      expect(copies, hasLength(1));
      expect(copies.single.shift, 0);
      expect(identical(copies.single.camera, camera), isTrue);
    });

    test('adds the world to the east when the view crosses 180', () {
      // At zoom 3 the world is 2048 px wide; centred on 170E, the right
      // half of an 800 px view is past the date line.
      final camera = _camera(longitude: 170);
      final copies = worldCopyCameras(camera);

      expect(copies.map((c) => c.shift), [0, 1]);

      // Tahiti (170W) belongs just right of centre, in the eastern copy.
      final east = copies.firstWhere((c) => c.shift == 1).camera;
      final tahiti = east.latLngToScreenOffset(const LatLng(0, -170));
      expect(tahiti.dx, closeTo(400 + 2048 * 20 / 360, 1.0));
    });

    test('adds the world to the west when the view crosses -180', () {
      final copies = worldCopyCameras(_camera(longitude: -170));
      expect(copies.map((c) => c.shift), [-1, 0]);
    });

    test('covers every repeat of a view wider than several worlds', () {
      // At zoom 1 the world is 512 px wide, so a 2000 px view shows parts
      // of five copies.
      final copies = worldCopyCameras(
        _camera(longitude: 0, zoom: 1, size: const Size(2000, 400)),
      );
      expect(copies.map((c) => c.shift), [-2, -1, 0, 1, 2]);
    });

    test('shifted copies report a world-wide visible longitude band', () {
      final camera = _camera(longitude: 170);
      final east = worldCopyCameras(camera).firstWhere((c) => c.shift == 1);

      expect(east.camera.visibleBounds.west, -180);
      expect(east.camera.visibleBounds.east, 180);
      expect(
        east.camera.visibleBounds.north,
        closeTo(camera.visibleBounds.north, 1e-9),
      );
    });

    test('adds spare copies on each side when asked for a margin', () {
      final copies = worldCopyCameras(
        _camera(longitude: 0, zoom: 5),
        margin: 1,
      );
      expect(copies.map((c) => c.shift), [-1, 0, 1]);
    });

    test('is just the camera for a CRS that does not repeat the world', () {
      final camera = _camera(longitude: 170, crs: const Epsg4326());
      expect(worldCopyCameras(camera), hasLength(1));
    });
  });

  group('WorldWrappedMarkerClusterLayer', () {
    Marker marker(String key, LatLng point) => Marker(
      point: point,
      width: 20,
      height: 20,
      child: SizedBox(key: ValueKey(key), width: 20, height: 20),
    );

    Future<void> pumpMap(WidgetTester tester, LatLng center) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
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
                  WorldWrappedMarkerClusterLayer(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 20,
                      size: const Size(30, 30),
                      markers: [
                        marker('australia', const LatLng(-20, 150)),
                        marker('tahiti', const LatLng(-17.5, -149.5)),
                      ],
                      builder: (context, markers) => const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('draws a marker from across the date line east of centre', (
      tester,
    ) async {
      await pumpMap(tester, const LatLng(-18, 175));

      final mapLeft = tester.getTopLeft(find.byType(FlutterMap)).dx;
      final tahiti = find.byKey(const ValueKey('tahiti'));
      final australia = find.byKey(const ValueKey('australia'));

      expect(tahiti, findsOneWidget);
      expect(australia, findsOneWidget);
      // 175E to 149.5W is 35.5 degrees east: right of centre, not off the
      // far left edge where the canonical world would put it.
      expect(
        tester.getCenter(tahiti).dx - mapLeft,
        closeTo(400 + 2048 * 35.5 / 360, 2.0),
      );
      expect(tester.getCenter(australia).dx - mapLeft, lessThan(400));
    });

    testWidgets('draws each marker once when no seam is in view', (
      tester,
    ) async {
      await pumpMap(tester, const LatLng(-18, 150));

      expect(find.byKey(const ValueKey('australia')), findsOneWidget);
    });
  });
}
