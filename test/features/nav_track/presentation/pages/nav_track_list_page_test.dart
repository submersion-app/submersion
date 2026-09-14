import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_service_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_list_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records `delete` calls instead of touching a real database.
class _RecordingNavTrackRepository extends NavTrackRepository {
  String? deletedId;

  @override
  Future<void> delete(String routeId) async {
    deletedId = routeId;
  }
}

/// Stubs `sweep()` with a canned result, or an error, instead of running a
/// real sweep against a database.
class _FakeNavTrackMatchService extends NavTrackMatchService {
  _FakeNavTrackMatchService({this.error})
    : super(
        routeRepository: NavTrackRepository(),
        diveRepository: DiveRepository(),
      );

  final Object? error;
  int callCount = 0;

  @override
  Future<({List<String> linked, List<String> needsChoice})> sweep({
    List<String>? limitToRouteIds,
    List<String>? limitToDiveIds,
  }) async {
    callCount++;
    if (error != null) throw error!;
    return (linked: const <String>[], needsChoice: const <String>[]);
  }
}

List<NavTrackPoint> _hydratedPoints() => [
  for (var i = 0; i < 5; i++)
    NavTrackPoint(
      timestamp: 1755856800 + i * 10,
      north: i * 10.0,
      east: 0,
      depth: 5,
    ),
];

NavTrack _route({
  required String id,
  String? diveId,
  String? name,
  String? deviceName,
  double? distance,
  double? maxDepth,
  double? anchorLatitude,
  double? anchorLongitude,
}) => NavTrack(
  id: id,
  diveId: diveId,
  linkMode: diveId == null ? null : NavTrackLinkMode.auto,
  name: name,
  deviceName: deviceName,
  source: NavTrackSource.seacraftEnc,
  sourceRef: '$id.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 5,
  totalDistance: distance,
  maxDepth: maxDepth,
  anchorLatitude: anchorLatitude,
  anchorLongitude: anchorLongitude,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Future<_RecordingNavTrackRepository> _pump(
  WidgetTester tester, {
  required List<NavTrack> routes,
  Dive? linkedDive,
  Map<String, NavTrack>? hydrated,
  NavTrackMatchService? matchService,
  MockSettingsNotifier? settingsNotifier,
}) async {
  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  final repository = _RecordingNavTrackRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        allNavTracksProvider.overrideWith((ref) async => routes),
        navTrackRepositoryProvider.overrideWithValue(repository),
        if (matchService != null)
          navTrackMatchServiceProvider.overrideWithValue(matchService),
        if (linkedDive != null)
          diveProvider(linkedDive.id).overrideWith((ref) async => linkedDive),
        if (hydrated != null)
          for (final entry in hydrated.entries)
            navTrackByIdProvider(
              entry.key,
            ).overrideWith((ref) async => entry.value),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NavTrackListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('renders route rows with distance, depth and an unlinked chip', (
    tester,
  ) async {
    await _pump(
      tester,
      routes: [
        _route(
          id: 'r1',
          name: 'Wreck dive',
          deviceName: 'Seacraft ENC3',
          distance: 1050,
          maxDepth: 38,
        ),
      ],
    );

    expect(find.text('Wreck dive'), findsOneWidget);
    expect(find.text('unlinked'), findsOneWidget);
  });

  testWidgets('a linked route shows a Dive # chip instead of unlinked', (
    tester,
  ) async {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 412,
      dateTime: DateTime(2026, 8, 22, 10, 8),
    );
    await _pump(
      tester,
      routes: [_route(id: 'r1', name: 'Wreck dive', diveId: 'dive-1')],
      linkedDive: dive,
    );

    expect(find.text('unlinked'), findsNothing);
    expect(find.textContaining('Dive'), findsOneWidget);
    expect(find.textContaining('#412'), findsOneWidget);
  });

  testWidgets('shows an empty message with no routes', (tester) async {
    await _pump(tester, routes: const []);

    expect(find.text('No underwater routes yet.'), findsOneWidget);
  });

  testWidgets(
    'the list row\'s date uses the wall-clock-as-UTC convention, not the '
    'host\'s local timezone (route.startTime, like dives.entryTime, is a '
    'wall-clock-as-UTC epoch)',
    (tester) async {
      // 23:30 UTC: on any host east of UTC (including this repo's own dev/CI
      // offset), a `.fromMillisecondsSinceEpoch` WITHOUT `isUtc: true` rolls
      // this over to the next local calendar day, changing the digits
      // `yyyymmdd` renders below. On a host west of UTC it would instead
      // roll BACK to 2026-03-27 -- either way, only isUtc: true keeps it at
      // 2026-03-28.
      final startTime = DateTime.utc(
        2026,
        3,
        28,
        23,
        30,
      ).millisecondsSinceEpoch;
      final settings = MockSettingsNotifier();
      await settings.setDateFormat(DateFormatPreference.yyyymmdd);

      await _pump(
        tester,
        routes: [
          _route(
            id: 'r1',
            name: 'Wreck dive',
          ).copyWith(startTime: startTime, endTime: startTime + 600000),
        ],
        settingsNotifier: settings,
      );

      expect(find.textContaining('2026-03-28'), findsOneWidget);
      expect(find.textContaining('2026-03-29'), findsNothing);
    },
  );

  testWidgets(
    'an unanchored route\'s shape thumbnail renders the actual route, not '
    'an empty shape (item 9: the list query omits points, so the thumbnail '
    'must hydrate them itself rather than reading the unhydrated list row)',
    (tester) async {
      final listRow = _route(id: 'r1', name: 'Wreck dive');
      final hydratedRoute = listRow.copyWith(points: _hydratedPoints());
      await _pump(tester, routes: [listRow], hydrated: {'r1': hydratedRoute});

      final thumbnail = tester.widget<NavTrackShapeThumbnail>(
        find.byType(NavTrackShapeThumbnail),
      );
      expect(thumbnail.points, isNotEmpty);
      expect(thumbnail.points, hydratedRoute.points);
    },
  );

  testWidgets(
    'the list row\'s duration stops at the last dead-reckoned sample, not '
    'the raw recording span (item 8: a GPS-fix jump and the post-surfacing '
    'tail must not inflate the displayed duration)',
    (tester) async {
      final points = [
        const NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 5),
        // Last active sample: 600 s (10 min) after the first.
        const NavTrackPoint(
          timestamp: 600,
          north: 50,
          east: 0,
          depth: 0.1,
          distance: 50,
        ),
        // Fix event: >50 m step in <=5 s at the surface -- gpsFixed from
        // here on, and NOT part of the active dead-reckoned range.
        const NavTrackPoint(
          timestamp: 602,
          north: 500,
          east: 0,
          depth: 0.1,
          distance: 50,
        ),
        // The raw recording keeps going for another hour after the fix.
        const NavTrackPoint(
          timestamp: 4200,
          north: 505,
          east: 0,
          depth: 0.1,
          distance: 50,
        ),
      ];
      final listRow = _route(id: 'r1', name: 'Wreck dive').copyWith(
        startTime: points.first.timestamp * 1000,
        endTime: points.last.timestamp * 1000,
      );
      final hydratedRoute = listRow.copyWith(points: points);
      await _pump(tester, routes: [listRow], hydrated: {'r1': hydratedRoute});

      // Active range: 10 min. Raw span: 1h 10min. Only the former may show.
      expect(find.textContaining('10min'), findsOneWidget);
      expect(find.textContaining('1h 10min'), findsNothing);
    },
  );

  testWidgets(
    'an anchored route\'s map overlay actually renders the route, not an '
    'empty polyline (item 9: the map pane must hydrate points per row too)',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final listRow = _route(
        id: 'r1',
        name: 'Wreck dive',
        anchorLatitude: 47.1,
        anchorLongitude: 8.3,
      );
      final hydratedRoute = listRow.copyWith(points: _hydratedPoints());
      await _pump(tester, routes: [listRow], hydrated: {'r1': hydratedRoute});

      expect(find.byType(FlutterMap), findsOneWidget);
      final layer = tester.widget<NavTrackPolylineLayer>(
        find.byType(NavTrackPolylineLayer),
      );
      expect(layer.route.points, isNotEmpty);
      expect(layer.route.points, hydratedRoute.points);
    },
  );

  group('delete', () {
    testWidgets('cancelling the dialog does not delete', (tester) async {
      final repository = await _pump(
        tester,
        routes: [_route(id: 'r1', name: 'Wreck dive')],
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Wreck dive"?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deletedId, isNull);
    });

    testWidgets('confirming the dialog deletes through the repository', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        routes: [_route(id: 'r1', name: 'Wreck dive')],
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deletedId, 'r1');
    });
  });

  group('match now', () {
    testWidgets('shows a success snackbar when the sweep succeeds', (
      tester,
    ) async {
      final service = _FakeNavTrackMatchService();
      await _pump(tester, routes: const [], matchService: service);

      await tester.tap(find.byKey(const ValueKey('nav-track-match')));
      await tester.pumpAndSettle();

      expect(service.callCount, 1);
      expect(find.text('Routes matched to dives.'), findsOneWidget);
    });

    testWidgets('shows an error snackbar when the sweep throws', (
      tester,
    ) async {
      final service = _FakeNavTrackMatchService(error: Exception('boom'));
      await _pump(tester, routes: const [], matchService: service);

      await tester.tap(find.byKey(const ValueKey('nav-track-match')));
      await tester.pumpAndSettle();

      expect(find.text('Could not match routes.'), findsOneWidget);
    });
  });

  group('master-detail (wide) layout', () {
    Future<void> widen(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
    }

    testWidgets('shows the no-map-routes message with no anchored routes', (
      tester,
    ) async {
      await widen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _pump(
        tester,
        routes: [_route(id: 'r1', name: 'Wreck dive')],
      );

      expect(find.text('No routes are placed on the map yet.'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('the map pane has a basemap tile layer (item 7)', (
      tester,
    ) async {
      await widen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _pump(
        tester,
        routes: [
          _route(
            id: 'r1',
            name: 'Wreck dive',
            anchorLatitude: 47.1,
            anchorLongitude: 8.3,
          ),
        ],
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
    });

    testWidgets(
      'the map pane fits its camera to the anchored routes rather than '
      'starting at flutter_map\'s default world view (item 7)',
      (tester) async {
        await widen(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await _pump(
          tester,
          routes: [
            _route(
              id: 'r1',
              name: 'Wreck dive',
              anchorLatitude: 47.1,
              anchorLongitude: 8.3,
            ),
          ],
        );

        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(
          map.options.initialCameraFit,
          isNotNull,
          reason:
              'with anchored routes present, the map must be handed a '
              'camera fit derived from their positions instead of relying '
              'on flutter_map\'s uninitialized default (center 0,0, zoom '
              '13)',
        );
      },
    );
  });
}
