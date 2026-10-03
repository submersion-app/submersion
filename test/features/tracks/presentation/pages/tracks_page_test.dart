import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_thumbnail.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/pages/tracks_page.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_summary_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/test_database.dart';

/// Hands back a fixed preview so the flow can be followed past the picker.
class _PreparedNavImport implements NavTrackImportService {
  int prepareCount = 0;

  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async {
    prepareCount++;
    const points = [
      NavTrackPoint(
        timestamp: 1755856800,
        north: 0,
        east: 0,
        depth: 5,
        distance: 0,
        speed: 0.3,
      ),
      NavTrackPoint(
        timestamp: 1755857400,
        north: 40,
        east: 0,
        depth: 5,
        distance: 40,
        speed: 0.3,
      ),
    ];
    return NavTrackImportPreview(
      parsed: const ParsedNavTrack(points: points),
      stats: NavTrackStats.of(points),
      segmentation: NavTrackSegmenter.classify(points),
      candidateDives: const [],
      nearbyDives: const [],
      duplicateOfRouteId: null,
      sourceRef: fileName ?? '',
    );
  }

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    required String? diverId,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
    String? replacingRouteId,
  }) async => throw UnimplementedError();
}

class _GpsMatch extends GpsTrackMatchService {
  _GpsMatch({this.result = const [], this.fail = false})
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );
  final List<String> result;
  final bool fail;

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    if (fail) throw StateError('sweep failed');
    return result;
  }
}

/// Holds every sweep open until [release], counting how many started.
class _GatedGpsMatch extends GpsTrackMatchService {
  _GatedGpsMatch()
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );
  final _gate = Completer<void>();
  int calls = 0;

  void release() => _gate.complete();

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    calls++;
    await _gate.future;
    return const [];
  }
}

/// Records deletes instead of touching the nav table.
class _RecordingNavRepository extends NavTrackRepository {
  String? deletedId;
  bool failDelete = false;

  @override
  Future<void> delete(String routeId) async {
    if (failDelete) throw StateError('database locked');
    deletedId = routeId;
  }
}

final _points = [
  for (var i = 0; i < 5; i++)
    NavTrackPoint(
      timestamp: 1755856800 + i * 10,
      north: i * 10.0,
      east: 0,
      depth: 5,
    ),
];

NavTrack _uw({bool anchored = false}) => NavTrack(
  id: 'r1',
  name: 'Wreck dive',
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  durationSeconds: 600,
  pointCount: 5,
  anchorLatitude: anchored ? 1.002 : null,
  anchorLongitude: anchored ? 2.002 : null,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

const _twoFixes = [
  GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
  GpsTrackPoint(timestamp: 1700000600, latitude: 1.003, longitude: 2.003),
];
const _desktop = Size(1400, 900);

void main() {
  late GpsTrackRepository repo;
  late _RecordingNavRepository navRepo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
    navRepo = _RecordingNavRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> seedGps() async {
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    await repo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
    );
    await repo.finalizeTrack(id, endTimeMs: 1700005400000);
    return id;
  }

  Future<Widget> app({
    List<NavTrack> underwater = const [],
    GpsTrackMatchService? gpsMatch,
    // Overrides the GPS list (for loading and error states); the default
    // reads the test database.
    Future<List<GpsTrack>> Function()? gpsTracks,
    Size? size,
    String initialLocation = '/tracks',
    Map<String, List<GpsTrackPoint>> geometry = const {},
    // Riverpod's sealed Override type is not re-exported; see test_app.dart.
    List<dynamic> extraOverrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/tracks',
          builder: (context, state) => TracksPage(
            initialKind: TrackKindFilter.fromQuery(
              state.uri.queryParameters['kind'],
            ),
          ),
        ),
        GoRoute(
          path: '/tracks/map',
          builder: (_, _) => const Scaffold(body: Text('MAP-PAGE')),
        ),
        GoRoute(
          path: '/tracks/gps/:id',
          builder: (_, _) => const Scaffold(body: Text('GPS-DETAIL')),
        ),
        GoRoute(
          path: '/tracks/underwater/:id',
          builder: (_, state) => Scaffold(
            body: Text('UNDERWATER-DETAIL ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/dives/match-sites',
          builder: (_, _) => const Scaffold(body: Text('MATCH-SITES-PAGE')),
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allNavTracksProvider.overrideWith((ref) async => underwater),
        navTrackRepositoryProvider.overrideWithValue(navRepo),
        // The pending-choice hint counts unlinked routes; derive them from
        // the fixture rather than reaching the diver lookup.
        unlinkedNavTracksProvider.overrideWith(
          (ref) async => [
            for (final track in underwater)
              if (track.diveId == null) track,
          ],
        ),
        if (gpsTracks != null)
          gpsTracksProvider.overrideWith((ref) => gpsTracks()),
        for (final track in underwater)
          navTrackByIdProvider(
            track.id,
          ).overrideWith((ref) async => track.copyWith(points: _points)),
        if (gpsMatch != null)
          gpsTrackMatchServiceProvider.overrideWithValue(gpsMatch),
        for (final entry in geometry.entries)
          gpsTrackGeometryProvider((
            entry.key,
            TrackLod.thumbnail,
          )).overrideWith((ref) async => entry.value),
        ...extraOverrides.cast(),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The breakpoint reads MediaQuery; setSurfaceSize alone is not what
        // the page sees.
        builder: size == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: size),
                child: child!,
              ),
      ),
    );
  }

  Finder row(String key) => find.byKey(ValueKey(key));
  Finder kindSegment(String label) => find.descendant(
    of: find.byKey(const ValueKey('tracks-kind-filter')),
    matching: find.text(label),
  );

  testWidgets('a desktop platform hides record controls; an empty library '
      'explains both kinds', (tester) async {
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('Start logging'), findsNothing);
    expect(find.text('No tracks yet'), findsOneWidget);
    expect(find.text('Match dives to GPS logs'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a phone shows the record card', (tester) async {
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('Start logging'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('both kinds share one list, newest first, each badged', (
    tester,
  ) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();

    final underwaterTop = tester.getTopLeft(row('underwater:r1')).dy;
    final gpsTop = tester.getTopLeft(row('gps:$gpsId')).dy;
    expect(
      underwaterTop,
      lessThan(gpsTop),
      reason: 'the 2025 underwater track is newer',
    );
    expect(find.byKey(const ValueKey('track-kind-badge-gps')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('track-kind-badge-underwater')),
      findsOneWidget,
    );
  });

  testWidgets('the kind filter narrows the list', (tester) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();

    await tester.tap(kindSegment('Underwater'));
    await tester.pumpAndSettle();
    expect(row('gps:$gpsId'), findsNothing);
    expect(row('underwater:r1'), findsOneWidget);
  });

  testWidgets('a kind link seeds the filter', (tester) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(
      await app(
        underwater: [_uw()],
        initialLocation: '/tracks?kind=underwater',
      ),
    );
    await tester.pumpAndSettle();
    expect(row('gps:$gpsId'), findsNothing);
    expect(row('underwater:r1'), findsOneWidget);
  });

  testWidgets('filters that hide everything say so, and clearing them '
      'restores the list', (tester) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    await tester.tap(kindSegment('Underwater'));
    await tester.pumpAndSettle();
    expect(find.text('No tracks match these filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(row('gps:$gpsId'), findsOneWidget);
  });

  testWidgets('on a phone a row opens its track', (tester) async {
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wreck dive'));
    await tester.pumpAndSettle();
    expect(find.text('UNDERWATER-DETAIL r1'), findsOneWidget);
  });

  testWidgets('match reports positioned dives and links to the site review', (
    tester,
  ) async {
    await tester.pumpWidget(
      await app(gpsMatch: _GpsMatch(result: const ['d1', 'd2'])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match dives to GPS logs'));
    await tester.pumpAndSettle();
    expect(find.text('2 dives positioned'), findsOneWidget);

    await tester.tap(find.text('Review site matches'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH-SITES-PAGE'), findsOneWidget);
  });

  testWidgets('match with nothing new says so', (tester) async {
    await tester.pumpWidget(await app(gpsMatch: _GpsMatch()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match dives to GPS logs'));
    await tester.pumpAndSettle();
    expect(find.text('No dives matched a recorded track'), findsOneWidget);
    expect(find.text('Review site matches'), findsNothing);
  });

  testWidgets('a failing match says so instead of throwing', (tester) async {
    await tester.pumpWidget(await app(gpsMatch: _GpsMatch(fail: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match dives to GPS logs'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('unlinked underwater tracks show the pending-choice hint', (
    tester,
  ) async {
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();
    expect(find.text('1 underwater track needs your choice'), findsOneWidget);
  });

  testWidgets('the list shows a spinner on first load, not the empty state', (
    tester,
  ) async {
    final pending = Completer<List<GpsTrack>>();
    await tester.pumpWidget(await app(gpsTracks: () => pending.future));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No tracks yet'), findsNothing);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No tracks yet'), findsOneWidget);
  });

  testWidgets('a failed list says so instead of claiming there are none', (
    tester,
  ) async {
    await tester.pumpWidget(
      await app(gpsTracks: () => Future.error(StateError('boom'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('No tracks yet'), findsNothing);
  });

  testWidgets('deleting a GPS track confirms, then removes it', (tester) async {
    final id = await seedGps();
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete track?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await repo.getTrack(id), isNull);
  });

  testWidgets('deleting an underwater track goes through its repository', (
    tester,
  ) async {
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Wreck dive"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(navRepo.deletedId, 'r1');
  });

  testWidgets('an interrupted recording surfaces a recovery notice', (
    tester,
  ) async {
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    await repo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
    );
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(
      find.text('A previous recording was interrupted. The track was saved.'),
      findsOneWidget,
    );
    expect(find.byType(GpsTrackThumbnail), findsOneWidget);
  });

  testWidgets('the summary counts both kinds', (tester) async {
    await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();
    final strip = find.byType(TracksSummaryStrip);
    // 1h 30m of GPS plus the 10-minute underwater dive.
    expect(
      find.descendant(of: strip, matching: find.text('1h 40m')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('2')),
      findsOneWidget,
    );
  });

  group('desktop split', () {
    testWidgets('the list sits beside one map drawing both kinds', (
      tester,
    ) async {
      final id = await seedGps();
      await tester.pumpWidget(
        await app(
          size: _desktop,
          underwater: [_uw(anchored: true)],
          geometry: {id: _twoFixes},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PolylineLayer<String>), findsOneWidget);
      expect(find.byType(NavTrackPolylineLayer), findsOneWidget);
      expect(find.byTooltip('Show map'), findsNothing);
    });

    testWidgets('a phone-width surface keeps the single column', (
      tester,
    ) async {
      final id = await seedGps();
      await tester.pumpWidget(
        await app(size: const Size(390, 844), geometry: {id: _twoFixes}),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PolylineLayer<String>), findsNothing);
      expect(find.byTooltip('Show map'), findsOneWidget);
    });

    testWidgets('a row selects its track; the info card opens it', (
      tester,
    ) async {
      final id = await seedGps();
      await tester.pumpWidget(
        await app(size: _desktop, geometry: {id: _twoFixes}),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsNothing);

      await tester.tap(find.text('1 point, 1h 30m'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsOneWidget);
      expect(find.text('GPS-DETAIL'), findsNothing);

      await tester.tap(find.byTooltip('View details'));
      await tester.pumpAndSettle();
      expect(find.text('GPS-DETAIL'), findsOneWidget);
    });

    testWidgets('an underwater row shows its own info card', (tester) async {
      await tester.pumpWidget(
        await app(size: _desktop, underwater: [_uw(anchored: true)]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wreck dive'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('View details'));
      await tester.pumpAndSettle();
      expect(find.text('UNDERWATER-DETAIL r1'), findsOneWidget);
    });

    testWidgets('a selection the kind filter hides loses its info card', (
      tester,
    ) async {
      // Both rows plus the header run past an 800x600 surface; size it to
      // the 1400x900 layout so the GPS row is hittable.
      await tester.binding.setSurfaceSize(_desktop);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final id = await seedGps();
      await tester.pumpWidget(
        await app(
          size: _desktop,
          underwater: [_uw(anchored: true)],
          geometry: {id: _twoFixes},
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 point, 1h 30m'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsOneWidget);

      await tester.tap(kindSegment('Underwater'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsNothing);
    });

    testWidgets('deleting the selected track clears its info card', (
      tester,
    ) async {
      final id = await seedGps();
      await tester.pumpWidget(
        await app(size: _desktop, geometry: {id: _twoFixes}),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 point, 1h 30m'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsNothing);
      expect(find.text('No tracks yet'), findsOneWidget);
      // The row is gone either way; the selection itself must be cleared too,
      // or a later track reusing the key would open preselected.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TracksPage)),
      );
      expect(
        container.read(mapListSelectionProvider(kTracksSectionKey)).selectedId,
        isNull,
      );
    });

    testWidgets('unanchored-only tracks say they have no map position', (
      tester,
    ) async {
      await tester.pumpWidget(await app(size: _desktop, underwater: [_uw()]));
      await tester.pumpAndSettle();
      expect(
        find.text('None of these tracks has a position on the map yet.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty library shows an empty basemap', (tester) async {
      await tester.pumpWidget(await app(size: _desktop));
      await tester.pumpAndSettle();
      expect(find.text('No recorded tracks to show.'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('a tablet wide enough for the split still records', (
      tester,
    ) async {
      await tester.pumpWidget(await app(size: _desktop));
      await tester.pumpAndSettle();
      expect(find.text('Start logging'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('the Import action sends an ENC log to the underwater review', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = [
        FakePlatformFile.contentUri(
          Uri.parse('content://picked/005.DAT.csv'),
          name: '005.DAT.csv',
          bytes: File(
            p.join('test', 'fixtures', 'nav_tracks', 'seacraft_enc3_short.csv'),
          ).readAsBytesSync(),
        ),
      ];
    await tester.pumpWidget(
      await app(
        extraOverrides: [
          navTrackImportServiceProvider.overrideWithValue(_PreparedNavImport()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tracks-import')));
    await tester.pumpAndSettle();

    expect(find.byType(NavTrackImportReviewPage), findsOneWidget);
  });

  testWidgets('a kind link arriving while Tracks is open applies it', (
    tester,
  ) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();
    expect(row('gps:$gpsId'), findsOneWidget);

    GoRouter.of(
      tester.element(find.byType(TracksPage)),
    ).go('/tracks?kind=underwater');
    await tester.pumpAndSettle();

    expect(row('gps:$gpsId'), findsNothing);
    expect(row('underwater:r1'), findsOneWidget);
  });

  testWidgets('on a phone the map button opens the full-screen map', (
    tester,
  ) async {
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show map'));
    await tester.pumpAndSettle();
    expect(find.text('MAP-PAGE'), findsOneWidget);
  });

  testWidgets('cancelling a delete keeps the track', (tester) async {
    final id = await seedGps();
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(await repo.getTrack(id), isNotNull);
    expect(row('gps:$id'), findsOneWidget);
  });

  testWidgets('closing the info card clears the selection', (tester) async {
    final id = await seedGps();
    await tester.pumpWidget(
      await app(size: _desktop, geometry: {id: _twoFixes}),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 point, 1h 30m'));
    await tester.pumpAndSettle();
    expect(find.byType(MapInfoCard), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(MapInfoCard),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MapInfoCard), findsNothing);
  });

  testWidgets('a second Match tap while one runs starts no second sweep', (
    tester,
  ) async {
    final gps = _GatedGpsMatch();
    await tester.pumpWidget(await app(gpsMatch: gps));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Match dives to GPS logs'));
    await tester.pump();
    await tester.tap(find.text('Match dives to GPS logs'), warnIfMissed: false);
    await tester.pump();
    expect(gps.calls, 1);

    gps.release();
    await tester.pumpAndSettle();
    expect(find.text('No dives matched a recorded track'), findsOneWidget);
  });

  testWidgets('an empty library keeps the onboarding text under a kind link', (
    tester,
  ) async {
    await tester.pumpWidget(
      await app(initialLocation: '/tracks?kind=underwater'),
    );
    await tester.pumpAndSettle();
    expect(find.text('No tracks yet'), findsOneWidget);
    expect(find.text('No tracks match these filters'), findsNothing);
  });

  testWidgets('the pending-choice hint hides while the list shows GPS only', (
    tester,
  ) async {
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();
    expect(find.text('1 underwater track needs your choice'), findsOneWidget);

    await tester.tap(kindSegment('GPS'));
    await tester.pumpAndSettle();
    expect(find.text('1 underwater track needs your choice'), findsNothing);
  });

  testWidgets('a failed delete says so and keeps the track', (tester) async {
    navRepo.failDelete = true;
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(row('underwater:r1'), findsOneWidget);
  });
}
