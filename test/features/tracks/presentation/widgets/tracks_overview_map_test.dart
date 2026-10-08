import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

GpsTrackPoint _p(int t, double base) => GpsTrackPoint(
  timestamp: t,
  latitude: base + t * 0.001,
  longitude: -87.0 + t * 0.001,
);

GpsTrack _gps(String id, double base) => GpsTrack(
  id: id,
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: 3,
  points: [_p(0, base), _p(1, base), _p(2, base)],
);

NavTrack _uw(
  String id, {
  double? lat,
  double? lon,
  List<NavTrackPoint> points = const [],
}) => NavTrack(
  id: id,
  source: NavTrackSource.seacraftEnc,
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: points.length,
  anchorLatitude: lat,
  anchorLongitude: lon,
  points: points,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _points = [
  for (var i = 0; i < 5; i++)
    NavTrackPoint(
      timestamp: 1755856800 + i * 10,
      north: i * 10.0,
      east: 0,
      depth: 5,
    ),
];

Future<MapController> _pump(
  WidgetTester tester, {
  required List<TrackListItem> items,
  String? selectedKey,
}) async {
  final controller = MapController();
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        for (final item in items)
          if (item is GpsTrackItem)
            gpsTrackGeometryProvider((
              item.id,
              TrackLod.thumbnail,
            )).overrideWith((ref) async => item.track.points),
        for (final item in items)
          if (item is UnderwaterTrackItem)
            navTrackByIdProvider(
              item.id,
            ).overrideWith((ref) async => item.track.copyWith(points: _points)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TracksOverviewMap(
            items: items,
            selectedKey: selectedKey,
            controller: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('tracksMapFramingSignature', () {
    test('changes when an anchored underwater track is realigned', () {
      String sig(double lat) => tracksMapFramingSignature(
        items: [UnderwaterTrackItem(_uw('a', lat: lat, lon: 8.3))],
        pointCount: 1,
        selectedKey: null,
      );
      expect(sig(46.9), isNot(sig(47.1)));
    });

    test('changes when a different track of the same size takes over', () {
      String sig(String id) => tracksMapFramingSignature(
        items: [GpsTrackItem(_gps(id, 20))],
        pointCount: 3,
        selectedKey: null,
      );
      expect(sig('day-1'), isNot(sig('day-2')));
    });

    test('stays the same for the same tracks at the same anchors', () {
      String sig() => tracksMapFramingSignature(
        items: [
          UnderwaterTrackItem(_uw('a', lat: 47.1, lon: 8.3)),
          GpsTrackItem(_gps('g', 20)),
        ],
        pointCount: 4,
        selectedKey: 'gps:g',
      );
      expect(sig(), sig());
    });
  });

  test('a list item resolves to its own detail location', () {
    expect(trackLocationOf(GpsTrackItem(_gps('g', 20))), '/tracks/gps/g');
    expect(
      trackLocationOf(UnderwaterTrackItem(_uw('u'))),
      '/tracks/underwater/u',
    );
  });

  testWidgets('draws GPS polylines and hydrated underwater tracks on one map', (
    tester,
  ) async {
    await _pump(
      tester,
      items: [
        GpsTrackItem(_gps('t1', 20)),
        GpsTrackItem(_gps('t2', 25)),
        UnderwaterTrackItem(_uw('u1', lat: 20.5, lon: -87.0)),
      ],
    );
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    final gps = tester.widget<PolylineLayer<String>>(
      find.byType(PolylineLayer<String>),
    );
    expect(gps.polylines.length, 2);
    final underwater = tester.widget<NavTrackPolylineLayer>(
      find.byType(NavTrackPolylineLayer),
    );
    expect(underwater.route.points, isNotEmpty);
  });

  testWidgets('a selected GPS track is drawn last with a thicker stroke', (
    tester,
  ) async {
    await _pump(
      tester,
      items: [GpsTrackItem(_gps('t1', 20)), GpsTrackItem(_gps('t2', 25))],
      selectedKey: 'gps:t1',
    );
    final layer = tester.widget<PolylineLayer<String>>(
      find.byType(PolylineLayer<String>),
    );
    expect(layer.polylines.last.hitValue, 'gps:t1');
    expect(layer.polylines.last.strokeWidth, 4.0);
  });

  testWidgets('an underwater-only map has no GPS layer', (tester) async {
    await _pump(
      tester,
      items: [UnderwaterTrackItem(_uw('u1', lat: 47.1, lon: 8.3))],
    );
    expect(find.byType(PolylineLayer<String>), findsNothing);
    expect(find.byType(NavTrackPolylineLayer), findsOneWidget);
  });

  testWidgets('selecting an underwater track frames its anchor', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      items: [
        GpsTrackItem(_gps('t1', 20)),
        UnderwaterTrackItem(_uw('u1', lat: 47.1, lon: 8.3)),
      ],
      selectedKey: 'underwater:u1',
    );
    expect(controller.camera.center.latitude, closeTo(47.1, 0.01));
    expect(controller.camera.center.longitude, closeTo(8.3, 0.01));
  });
}
