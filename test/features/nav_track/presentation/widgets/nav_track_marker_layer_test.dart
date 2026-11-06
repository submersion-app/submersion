import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_marker.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_marker_layer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _anchor = GeoPoint(47.0, 8.0);

/// A short dive with a GPS fix at the surface after it: the last two rows
/// are the fix and its settled position, which the map does not draw.
const _points = [
  NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 2, distance: 0),
  NavTrackPoint(timestamp: 2, north: 10, east: 0, depth: 12, distance: 10),
  NavTrackPoint(timestamp: 4, north: 20, east: 0, depth: 20, distance: 20),
  NavTrackPoint(timestamp: 6, north: 25, east: 0, depth: 0, distance: 25),
  NavTrackPoint(timestamp: 8, north: 125, east: 0, depth: 0, distance: 25),
  NavTrackPoint(timestamp: 10, north: 126, east: 0, depth: 0, distance: 25),
];

NavTrack _route({
  List<NavTrackMarker> markers = const [],
  GeoPoint? anchor = _anchor,
  double headingOffsetDeg = 0,
}) => NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  sourceRef: '011.DAT.csv',
  startTime: 0,
  endTime: 10000,
  pointCount: _points.length,
  anchorLatitude: anchor?.latitude,
  anchorLongitude: anchor?.longitude,
  headingOffsetDeg: headingOffsetDeg,
  points: _points,
  markers: markers,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  group('navTrackMarkerPlacements (issue #4231)', () {
    test('numbers the markers in file order and places each on its sample', () {
      final placements = navTrackMarkerPlacements(
        _route(
          markers: const [
            NavTrackMarker(index: 1, rawValue: -1),
            NavTrackMarker(index: 2, rawValue: -101),
          ],
        ),
      );

      expect(placements.map((p) => p.number), [1, 2]);
      expect(placements.first.point, _points[1]);
      expect(placements.last.point, _points[2]);
      // 10 m and 20 m north of the anchor.
      expect(placements.first.latLng.latitude, greaterThan(_anchor.latitude));
      expect(
        placements.last.latLng.latitude,
        greaterThan(placements.first.latLng.latitude),
      );
      expect(placements.first.latLng.longitude, closeTo(8.0, 1e-9));
    });

    test('a marker after the dive keeps the numbering but is not drawn', () {
      final placements = navTrackMarkerPlacements(
        _route(
          markers: const [
            NavTrackMarker(index: 1, rawValue: -1),
            NavTrackMarker(index: 5, rawValue: -101),
          ],
        ),
      );

      expect(placements.map((p) => p.number), [1]);
    });

    test('a marker follows the correction the line does', () {
      const markers = [NavTrackMarker(index: 2, rawValue: -101)];
      final plain = navTrackMarkerPlacements(_route(markers: markers));
      final rotated = navTrackMarkerPlacements(
        _route(markers: markers, headingOffsetDeg: 90),
      );

      // 20 m north turned a quarter clockwise is 20 m east.
      expect(
        rotated.single.latLng.longitude,
        greaterThan(plain.single.latLng.longitude),
      );
      expect(rotated.single.latLng.latitude, closeTo(_anchor.latitude, 1e-6));
    });

    test('a route without an anchor or without markers places none', () {
      expect(navTrackMarkerPlacements(_route()), isEmpty);
      expect(
        navTrackMarkerPlacements(
          _route(
            anchor: null,
            markers: const [NavTrackMarker(index: 1, rawValue: -1)],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('NavTrackMarkerLayer', () {
    Future<void> pump(WidgetTester tester, NavTrack route) async {
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: base,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(47.0001, 8.0),
                  initialZoom: 18,
                ),
                children: [NavTrackMarkerLayer(route: route)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('draws a numbered dot per marker that names its depth', (
      tester,
    ) async {
      await pump(
        tester,
        _route(
          markers: const [
            NavTrackMarker(index: 1, rawValue: -1),
            NavTrackMarker(index: 2, rawValue: -101),
          ],
        ),
      );

      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find.byKey(const ValueKey('nav-track-marker-2')),
      );
      expect(tooltip.message, startsWith('Marker 2: '));
      expect(tooltip.message, contains('20'));
      // To the second: the sample sits 4 s into the recording, and markers
      // are often only seconds apart.
      expect(tooltip.message, contains(':04'));
    });

    testWidgets('draws nothing for a route without markers', (tester) async {
      await pump(tester, _route());

      expect(find.byType(MarkerLayer), findsNothing);
    });
  });

  test('a route keeps the end correction a marker sits on', () {
    // The corrector is what moves the line; the placements read through it,
    // so a same-as-start end pulls the last drawn marker back as well.
    final corrected = navTrackMarkerPlacements(
      _route(
        markers: const [NavTrackMarker(index: 3, rawValue: -101)],
      ).withCorrection(
        const NavTrackCorrection(
          anchor: _anchor,
          endMode: NavTrackEndMode.sameAsStart,
        ),
      ),
    );

    expect(corrected.single.latLng.latitude, closeTo(_anchor.latitude, 1e-6));
  });
}
