import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';

NavTrack _route({GeoPoint? anchor, List<NavTrackPoint> points = const []}) =>
    NavTrack(
      id: 'r1',
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'r1.csv',
      startTime: 1755856800000,
      endTime: 1755860400000,
      pointCount: points.length,
      anchorLatitude: anchor?.latitude,
      anchorLongitude: anchor?.longitude,
      points: points,
      createdAt: DateTime(2026, 8, 22),
      updatedAt: DateTime(2026, 8, 22),
    );

void main() {
  testWidgets('renders nothing without an anchor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: LatLng(0, 0)),
            children: [
              NavTrackPolylineLayer(
                route: _route(
                  points: [
                    const NavTrackPoint(
                      timestamp: 0,
                      north: 0,
                      east: 0,
                      depth: 1,
                    ),
                    const NavTrackPoint(
                      timestamp: 10,
                      north: 5,
                      east: 5,
                      depth: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byType(MarkerLayer), findsNothing);
  });

  testWidgets('draws polylines and start/end glyphs once anchored', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: LatLng(47.0, 8.0)),
            children: [
              NavTrackPolylineLayer(
                route: _route(
                  anchor: const GeoPoint(47.0, 8.0),
                  points: [
                    const NavTrackPoint(
                      timestamp: 0,
                      north: 0,
                      east: 0,
                      depth: 1,
                    ),
                    const NavTrackPoint(
                      timestamp: 10,
                      north: 5,
                      east: 5,
                      depth: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
  });

  testWidgets(
    'stops at the first fix event even when the diver re-descends later '
    '(never draws a second tail past the GPS jump)',
    (tester) async {
      final route = _route(
        anchor: const GeoPoint(47.0, 8.0),
        points: [
          const NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 5),
          const NavTrackPoint(timestamp: 10, north: 5, east: 0, depth: 0.1),
          // Fix event: >50 m step in <=5 s at the surface.
          const NavTrackPoint(timestamp: 12, north: 400, east: 0, depth: 0.1),
          const NavTrackPoint(timestamp: 20, north: 405, east: 0, depth: 0.1),
          // Re-descend: depth rises back above the surface threshold, so
          // the segmenter classifies this run as `underwater` again -- the
          // layer must still stop at the first fix event, not resume
          // drawing here.
          const NavTrackPoint(timestamp: 30, north: 410, east: 0, depth: 6),
          const NavTrackPoint(timestamp: 40, north: 420, east: 0, depth: 7),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: const MapOptions(initialCenter: LatLng(47.0, 8.0)),
              children: [NavTrackPolylineLayer(route: route)],
            ),
          ),
        ),
      );

      final polylines = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines;
      // Only the one pre-fix segment (north 0 -> 5): none of its points
      // reach as far north as the re-descended run (north >= 400).
      expect(polylines, hasLength(1));
      for (final polyline in polylines) {
        for (final point in polyline.points) {
          expect(point.latitude, lessThan(47.001));
        }
      }
    },
  );
}
