import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/coordinates/coordinate_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_content.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_marker.dart';
import 'package:submersion/features/media/presentation/widgets/media_place_strip.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

MediaMapPoint _point(
  String id, {
  LatLng at = const LatLng(12.5, 43.2),
  String? label = 'Blue Hole',
  bool favorite = false,
}) => MediaMapPoint(
  entry: MediaLibraryEntry(
    item: MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'asset-$id',
      isFavorite: favorite,
      takenAt: DateTime(2026, 3, 12),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    ),
  ),
  point: at,
  placement: MediaPlacement.diveSite,
  placeLabel: label,
);

class _SeededMapNotifier extends StateNotifier<MediaMapState>
    implements MediaMapNotifier {
  _SeededMapNotifier(super.state);

  void seed(MediaMapState next) => state = next;

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Opened {
  List<MediaItem>? items;
  String? initialId;
}

Future<_SeededMapNotifier> _pump(
  WidgetTester tester, {
  required MediaMapState state,
  _Opened? opened,
  MockSettingsNotifier? settings,
}) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final base = await getBaseOverrides(settingsNotifier: settings);
  final notifier = _SeededMapNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        mediaMapPointsProvider.overrideWith((ref) => notifier),
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
        mediaStoreIdentityProvider.overrideWith((ref) async => null),
        currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
        mediaServingRecorderProvider.overrideWithValue(MediaServingRecorder()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaMapContent(
            openViewer: (context, items, id) {
              opened?.items = items;
              opened?.initialId = id;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return notifier;
}

/// flutter_map's double-tap disambiguation timer must be flushed before
/// teardown or the test fails on a pending timer.
Future<void> _flushMapTimers(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  testWidgets('renders the map with one thumbnail marker per point', (
    tester,
  ) async {
    await _pump(
      tester,
      state: MediaMapState(
        points: [
          _point('a'),
          _point('b', at: const LatLng(-8, 115)),
        ],
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(MediaMapMarker), findsNWidgets(2));
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    await _flushMapTimers(tester);
  });

  testWidgets('no points shows the empty card, and the unlocated label still '
      'shows its count', (tester) async {
    await _pump(
      tester,
      state: const MediaMapState(points: [], unlocatedCount: 3),
    );

    expect(find.text('No media with a location'), findsOneWidget);
    expect(find.text('3 items without a location'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushMapTimers(tester);
  });

  testWidgets('the unlocated label is absent at zero', (tester) async {
    await _pump(tester, state: MediaMapState(points: [_point('a')]));

    expect(find.textContaining('without a location'), findsNothing);
    await _flushMapTimers(tester);
  });

  testWidgets('loading with nothing yet shows a spinner', (tester) async {
    await _pump(tester, state: const MediaMapState(isLoading: true));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('an error with nothing loaded shows the retry card', (
    tester,
  ) async {
    await _pump(tester, state: MediaMapState(error: StateError('boom')));

    expect(
      find.textContaining('Error loading media locations'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a single marker tap opens the viewer on that item', (
    tester,
  ) async {
    final opened = _Opened();
    await _pump(
      tester,
      state: MediaMapState(points: [_point('a')]),
      opened: opened,
    );

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();

    expect(opened.initialId, 'a');
    expect(opened.items?.map((m) => m.id), ['a']);
    await _flushMapTimers(tester);
  });

  testWidgets('a co-located cluster opens the place strip even at world '
      'zoom, and a background tap closes it', (tester) async {
    final opened = _Opened();
    await _pump(
      tester,
      state: MediaMapState(
        points: [_point('a'), _point('b'), _point('c', favorite: true)],
      ),
      opened: opened,
    );

    // Three points at one location render as a single cluster tile.
    expect(find.byType(MediaMapMarker), findsOneWidget);
    expect(
      find.byKey(const ValueKey('media-map-cluster-badge')),
      findsOneWidget,
    );
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);

    // A strip tile opens the viewer with the whole stack as the sequence.
    await tester.tap(find.byKey(const ValueKey('media-place-strip-tile-b')));
    await tester.pump();
    expect(opened.initialId, 'b');
    expect(opened.items?.map((m) => m.id), ['a', 'b', 'c']);

    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
    );
    await _flushMapTimers(tester);
    expect(find.byType(MediaPlaceStrip), findsNothing);
  });

  testWidgets('the cluster representative is the favorite', (tester) async {
    await _pump(
      tester,
      state: MediaMapState(points: [_point('a'), _point('b', favorite: true)]),
    );

    final marker = tester.widget<MediaMapMarker>(find.byType(MediaMapMarker));
    expect(marker.item.id, 'b');
    expect(marker.count, 2);
    await _flushMapTimers(tester);
  });

  testWidgets('a point reload without a filter change keeps the camera', (
    tester,
  ) async {
    final notifier = await _pump(
      tester,
      state: MediaMapState(points: [_point('a')]),
    );
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final controller = map.mapController!;
    final fittedZoom = controller.camera.zoom;
    expect(fittedZoom, closeTo(12, 1e-6), reason: 'first load fits');

    controller.move(const LatLng(0, 0), 4);
    await tester.pump();

    notifier.seed(
      MediaMapState(
        points: [
          _point('a'),
          _point('d', at: const LatLng(1, 1)),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.camera.zoom, closeTo(4, 1e-6));
    expect(controller.camera.center.latitude, closeTo(0, 1e-6));
    await _flushMapTimers(tester);
  });

  testWidgets('a marker that stays on screen keeps its thumbnail state '
      'across a zoom change', (tester) async {
    await _pump(tester, state: MediaMapState(points: [_point('a')]));
    final before = tester.state(find.byType(MediaItemView));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.mapController!.move(const LatLng(12.5, 43.2), 13);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(identical(tester.state(find.byType(MediaItemView)), before), isTrue);
    await _flushMapTimers(tester);
  });

  // Final review fixes.

  testWidgets('a co-located cluster tap opens the strip without also '
      'spiderfying the stack over the map', (tester) async {
    await _pump(
      tester,
      state: MediaMapState(points: [_point('a'), _point('b'), _point('c')]),
    );

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    // Still one tile on the map: the strip replaces the fan, it does not
    // sit under one.
    expect(find.byType(MediaMapMarker), findsOneWidget);
    await _flushMapTimers(tester);
  });

  testWidgets('a cluster tap past the dive map cap zooms in, never out', (
    tester,
  ) async {
    // Two own-GPS photos about 30 m apart: one cluster until very close in.
    const a = LatLng(12.5000, 43.2000);
    const b = LatLng(12.5002, 43.2002);
    await _pump(
      tester,
      state: MediaMapState(
        points: [
          _point('a', at: a),
          _point('b', at: b),
        ],
      ),
    );
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(12.5001, 43.2001), 16);
    await tester.pump();
    // The cluster plugin animates its own re-clustering after a zoom change
    // and ignores cluster taps while it does, so let that finish first.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MediaMapMarker), findsOneWidget, reason: 'clustered');

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(controller.camera.zoom, greaterThan(16.01));
    await _flushMapTimers(tester);
  });

  testWidgets('opening and closing the strip keeps the cluster thumbnail '
      'state', (tester) async {
    await _pump(
      tester,
      state: MediaMapState(points: [_point('a'), _point('b')]),
    );
    State clusterThumb() => tester.state(
      find.descendant(
        of: find.byType(MediaMapMarker),
        matching: find.byType(MediaItemView),
      ),
    );
    final before = clusterThumb();

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    expect(identical(clusterThumb(), before), isTrue);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(identical(clusterThumb(), before), isTrue);
    await _flushMapTimers(tester);
  });

  testWidgets('a background reload with points on screen shows no spinner', (
    tester,
  ) async {
    await _pump(
      tester,
      state: MediaMapState(points: [_point('a')], isLoading: true),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await _flushMapTimers(tester);
  });

  testWidgets('a filter change that reloads through an empty loading state '
      'refits to the new points without touching a detached map', (
    tester,
  ) async {
    final notifier = await _pump(
      tester,
      state: MediaMapState(points: [_point('a')]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaMapContent)),
    );

    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo);
    await tester.pump();
    notifier.seed(const MediaMapState(isLoading: true));
    await tester.pump();
    expect(find.byType(FlutterMap), findsNothing);

    notifier.seed(
      MediaMapState(points: [_point('b', at: const LatLng(-8, 115))]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    expect(controller.camera.center.latitude, closeTo(-8, 1e-6));
    expect(controller.camera.zoom, closeTo(12, 1e-6));
    await _flushMapTimers(tester);
  });

  testWidgets('a diver change refits the camera', (tester) async {
    final notifier = await _pump(
      tester,
      state: MediaMapState(points: [_point('a')]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaMapContent)),
    );
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;

    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d2');
    await tester.pump();
    notifier.seed(
      MediaMapState(points: [_point('c', at: const LatLng(-8, 115))]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.camera.center.latitude, closeTo(-8, 1e-6));
    await _flushMapTimers(tester);
  });

  // Coverage of the remaining map paths.

  testWidgets('a stack with no site name is titled by its coordinates in the '
      "diver's coordinate format", (tester) async {
    final settings = MockSettingsNotifier();
    await settings.setCoordinateFormat(CoordinateFormat.degreesMinutesSeconds);
    await _pump(
      tester,
      settings: settings,
      state: MediaMapState(
        points: [_point('a', label: null), _point('b', label: null)],
      ),
    );

    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        formatCoordinates(12.5, 43.2, CoordinateFormat.degreesMinutesSeconds),
      ),
      findsOneWidget,
    );
    await _flushMapTimers(tester);
  });

  testWidgets('the fit-all button refits the camera to every point', (
    tester,
  ) async {
    await _pump(
      tester,
      state: MediaMapState(
        points: [
          _point('a'),
          _point('b', at: const LatLng(-8, 115)),
        ],
      ),
    );
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(60, -100), 10);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();

    // Centred between the two points, not where the diver had panned to.
    expect(controller.camera.center.latitude, closeTo(2.25, 1.0));
    expect(controller.camera.zoom, lessThan(10));
    await _flushMapTimers(tester);
  });

  testWidgets('retry on the error card reloads the map points', (tester) async {
    var builds = 0;
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaMapPointsProvider.overrideWith((ref) {
            builds++;
            return _SeededMapNotifier(MediaMapState(error: StateError('x')));
          }),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaMapContent()),
        ),
      ),
    );
    await tester.pump();
    expect(builds, 1);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(builds, 2);
  });

  // The place strip holds a snapshot of a stack; it must not outlive the
  // point list it was taken from.

  Future<_SeededMapNotifier> openStrip(
    WidgetTester tester, {
    List<MediaMapPoint>? points,
  }) async {
    final notifier = await _pump(
      tester,
      state: MediaMapState(points: points ?? [_point('a'), _point('b')]),
    );
    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    return notifier;
  }

  testWidgets('a filter change closes an open strip', (tester) async {
    await openStrip(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaMapContent)),
    );

    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo);
    await tester.pump();

    expect(find.byType(MediaPlaceStrip), findsNothing);
    await _flushMapTimers(tester);
  });

  testWidgets('a diver change closes an open strip', (tester) async {
    await openStrip(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaMapContent)),
    );

    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d2');
    await tester.pump();

    expect(find.byType(MediaPlaceStrip), findsNothing);
    await _flushMapTimers(tester);
  });

  testWidgets('a reload with a different point list closes an open strip', (
    tester,
  ) async {
    final notifier = await openStrip(tester);

    // Item b was deleted in the background.
    notifier.seed(MediaMapState(points: [_point('a')]));
    await tester.pump();

    expect(find.byType(MediaPlaceStrip), findsNothing);
    await _flushMapTimers(tester);
  });

  testWidgets('a reload that keeps the same point list leaves the strip open', (
    tester,
  ) async {
    final same = [_point('a'), _point('b')];
    final notifier = await openStrip(tester, points: same);

    notifier.seed(MediaMapState(points: same, unlocatedCount: 3));
    await tester.pump();

    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    await _flushMapTimers(tester);
  });

  // Store availability changes must reach mounted tiles without disturbing
  // the clusters or the strip.

  MediaMapPoint stamped(MediaMapPoint p) => MediaMapPoint(
    entry: MediaLibraryEntry(
      item: p.item.copyWith(
        contentHash: 'abc123',
        remoteThumbUploadedAt: DateTime.utc(2026, 9, 25),
      ),
    ),
    point: p.point,
    placement: p.placement,
    placeLabel: p.placeLabel,
  );

  testWidgets('an upload-stamp reload hands a single marker the fresh item', (
    tester,
  ) async {
    final notifier = await _pump(
      tester,
      state: MediaMapState(points: [_point('a')]),
    );

    notifier.seed(MediaMapState(points: [stamped(_point('a'))]));
    await tester.pump();

    final marker = tester.widget<MediaMapMarker>(find.byType(MediaMapMarker));
    expect(marker.item.remoteThumbUploadedAt, DateTime.utc(2026, 9, 25));
    await _flushMapTimers(tester);
  });

  testWidgets('an upload-stamp reload keeps the cluster tile and the open '
      'strip, and both show the fresh items', (tester) async {
    final notifier = await openStrip(tester);
    State clusterThumb() => tester.state(
      find.descendant(
        of: find.byType(MediaMapMarker),
        matching: find.byType(MediaItemView),
      ),
    );
    final before = clusterThumb();

    notifier.seed(
      MediaMapState(points: [stamped(_point('a')), stamped(_point('b'))]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    expect(identical(clusterThumb(), before), isTrue, reason: 'no re-cluster');
    final clusterTile = tester.widget<MediaMapMarker>(
      find.byType(MediaMapMarker),
    );
    expect(clusterTile.item.contentHash, 'abc123');
    final strip = tester.widget<MediaPlaceStrip>(find.byType(MediaPlaceStrip));
    expect(strip.points.every((p) => p.item.contentHash == 'abc123'), isTrue);
    await _flushMapTimers(tester);
  });

  testWidgets('an in-flight cluster zoom stops when the map unmounts, so it '
      'cannot overwrite the next fit', (tester) async {
    const a = LatLng(12.5000, 43.2000);
    const b = LatLng(12.5002, 43.2002);
    final notifier = await _pump(
      tester,
      state: MediaMapState(
        points: [
          _point('a', at: a),
          _point('b', at: b),
        ],
      ),
    );
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(12.5001, 43.2001), 16);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Start the 800 ms cluster zoom, then change the filter mid-flight.
    await tester.tap(find.byType(MediaMapMarker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaMapContent)),
    );
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo);
    notifier.seed(const MediaMapState(isLoading: true));
    await tester.pump();
    notifier.seed(
      MediaMapState(points: [_point('c', at: const LatLng(-8, 115))]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(controller.camera.center.latitude, closeTo(-8, 1e-6));
    expect(controller.camera.zoom, closeTo(12, 1e-6));
    await _flushMapTimers(tester);
  });

  testWidgets('a failed reload with markers on screen shows a retry control '
      'that reloads the points', (tester) async {
    var builds = 0;
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          mediaMapPointsProvider.overrideWith((ref) {
            builds++;
            return _SeededMapNotifier(
              MediaMapState(points: [_point('a')], error: StateError('x')),
            );
          }),
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaMapContent()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The markers stay, and the failure is no longer silent.
    expect(find.byType(MediaMapMarker), findsOneWidget);
    expect(find.byIcon(Icons.sync_problem), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sync_problem));
    await tester.pump();
    expect(builds, 2);
    await _flushMapTimers(tester);
  });

  testWidgets('a nested cluster with no favorite shows its oldest item, not '
      "the plugin's traversal order", (tester) async {
    // Library (date) order: a, b, c. a and c sit together and b is about a
    // kilometre away, so at zoom 12 the plugin nests {a, c} under the
    // cluster and lists b first.
    await _pump(
      tester,
      state: MediaMapState(
        points: [
          _point('a', at: const LatLng(12.5000, 43.2000)),
          _point('b', at: const LatLng(12.5060, 43.2060)),
          _point('c', at: const LatLng(12.50005, 43.20005)),
        ],
      ),
    );
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(12.503, 43.203), 12);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final tile = tester.widget<MediaMapMarker>(find.byType(MediaMapMarker));
    expect(tile.count, 3);
    expect(tile.item.id, 'a');
    await _flushMapTimers(tester);
  });

  testWidgets('a site rename updates the title of an open strip', (
    tester,
  ) async {
    final notifier = await openStrip(tester);
    expect(find.text('Blue Hole'), findsOneWidget);

    notifier.seed(
      MediaMapState(
        points: [
          _point('a', label: 'Blue Hole North'),
          _point('b', label: 'Blue Hole North'),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(MediaPlaceStrip), findsOneWidget);
    expect(find.text('Blue Hole North'), findsOneWidget);
    await _flushMapTimers(tester);
  });
}
