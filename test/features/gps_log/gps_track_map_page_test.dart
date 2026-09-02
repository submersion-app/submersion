import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_map_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../helpers/mock_providers.dart';

GpsTrackPoint p(int t, double base) => GpsTrackPoint(
  timestamp: t,
  latitude: base + t * 0.001,
  longitude: -87.0 + t * 0.001,
);

GpsTrack _track(String id, double base) => GpsTrack(
  id: id,
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: 3,
  points: [p(0, base), p(1, base), p(2, base)],
);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
  List<GpsTrack>? tracks,
  // Thumbnail-LOD geometry per track; defaults to the track's own points.
  Future<List<GpsTrackPoint>> Function(GpsTrack track)? geometry,
}) async {
  final base = await getBaseOverrides();
  final data = tracks ?? [_track('t1', 20.0), _track('t2', 25.0)];
  final resolve = geometry ?? (t) async => t.points;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTracksProvider.overrideWith((ref) async => data),
        for (final t in data)
          gpsTrackGeometryProvider((
            t.id,
            TrackLod.thumbnail,
          )).overrideWith((ref) => resolve(t)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // MapListScaffold branches on MediaQuery width (>=1100 is the
        // master-detail split). Set it explicitly, matching
        // map_list_scaffold_test - setSurfaceSize alone is not what the
        // breakpoint reads.
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const GpsTrackMapPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws every track on one map', (tester) async {
    await _pump(tester);
    // The desktop layout also renders a thumbnail map per list row, so scope
    // to PolylineLayer<String>, which only the overview map emits.
    final layer = tester.widget<PolylineLayer<String>>(
      find.byType(PolylineLayer<String>),
    );
    expect(layer.polylines.length, 2);
  });

  testWidgets('shows the title and a list pane on a desktop surface', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Track Map'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('shows only the map on a phone-width surface', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('shows an empty basemap when there are no tracks', (
    tester,
  ) async {
    await _pump(tester, tracks: const []);
    expect(find.text('No recorded tracks to show.'), findsOneWidget);
    // A map still fills the pane; it just has nothing drawn on it.
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer<String>), findsNothing);
  });

  testWidgets('selecting a track promotes it to a thicker stroke', (
    tester,
  ) async {
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GpsTrackMapPage)),
    );
    container
        .read(mapListSelectionProvider('gps-tracks').notifier)
        .select('t1');
    await tester.pumpAndSettle();

    final layer = tester.widget<PolylineLayer<String>>(
      find.byType(PolylineLayer<String>),
    );
    // The selected line is drawn last so it sits above any it overlaps.
    expect(layer.polylines.last.hitValue, 't1');
    expect(layer.polylines.last.strokeWidth, 4.0);
    expect(layer.polylines.first.strokeWidth, 2.0);
  });

  testWidgets('selecting a track frames the map on that track alone', (
    tester,
  ) async {
    await _pump(tester);
    // Thumbnails are FlutterMaps too; only the overview map has a controller.
    FlutterMap overview() => tester.widget<FlutterMap>(
      find.byWidgetPredicate((w) => w is FlutterMap && w.mapController != null),
    );
    double centreLat() => overview().mapController!.camera.center.latitude;
    // Nothing selected: the whole library is framed, midway between t1 at
    // 20 degrees and t2 at 25.
    expect(centreLat(), closeTo(22.5, 1.0));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GpsTrackMapPage)),
    );
    container
        .read(mapListSelectionProvider('gps-tracks').notifier)
        .select('t2');
    await tester.pumpAndSettle();

    expect(centreLat(), closeTo(25.0, 0.1));

    // Clearing the selection frames the library again.
    container.read(mapListSelectionProvider('gps-tracks').notifier).deselect();
    await tester.pumpAndSettle();
    expect(centreLat(), closeTo(22.5, 1.0));
  });

  testWidgets('mounts the basemap before geometry arrives and frames once it '
      'does', (tester) async {
    // A cold cache decodes and simplifies every track in an isolate; until
    // the first one lands there is nothing to frame.
    final pending = Completer<List<GpsTrackPoint>>();
    final track = _track('t2', 25.0);
    await _pump(tester, tracks: [track], geometry: (_) => pending.future);

    FlutterMap overview() => tester.widget<FlutterMap>(
      find.byWidgetPredicate((w) => w is FlutterMap && w.mapController != null),
    );
    // The map is already on screen, drawing nothing yet.
    expect(overview, returnsNormally);
    final layer = tester.widget<PolylineLayer<String>>(
      find.byType(PolylineLayer<String>),
    );
    expect(layer.polylines, isEmpty);

    pending.complete(track.points);
    await tester.pumpAndSettle();

    expect(
      overview().mapController!.camera.center.latitude,
      closeTo(25.0, 0.1),
    );
  });

  testWidgets('the date filter starts unbounded', (tester) async {
    await _pump(tester);
    expect(find.text('All dates'), findsOneWidget);
    // No clear button until a range is actually set.
    expect(
      find.byKey(const ValueKey('gps-track-date-filter-clear')),
      findsNothing,
    );
  });

  testWidgets('shows a spinner while loading, not the empty state', (
    tester,
  ) async {
    // Reading `value ?? []` as authoritative flashed "No recorded tracks" on
    // every cold open and after every filter change.
    final gate = Completer<List<GpsTrack>>();
    final base = await getBaseOverrides();
    const size = Size(1400, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTracksProvider.overrideWith((ref) => gate.future),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: GpsTrackMapPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No recorded tracks to show.'), findsNothing);

    gate.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No recorded tracks to show.'), findsOneWidget);
  });

  testWidgets('a failed query says so instead of claiming there are none', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    const size = Size(1400, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTracksProvider.overrideWith(
            (ref) async => throw Exception('db down'),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: GpsTrackMapPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No recorded tracks to show.'), findsNothing);
  });
}
