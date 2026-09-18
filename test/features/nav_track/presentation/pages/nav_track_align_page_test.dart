import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_align_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records `updateCorrection` calls instead of touching a real database.
class _RecordingNavTrackRepository extends NavTrackRepository {
  String? lastRouteId;
  NavTrackCorrection? lastCorrection;

  @override
  Future<void> updateCorrection(
    String routeId,
    NavTrackCorrection correction,
  ) async {
    lastRouteId = routeId;
    lastCorrection = correction;
  }
}

List<NavTrackPoint> _points() => [
  for (var i = 0; i < 10; i++)
    NavTrackPoint(
      timestamp: 1755856800 + i * 10,
      north: i * 10.0,
      east: i * 5.0,
      depth: 5.0 + i,
      distance: i * 11.0,
    ),
];

NavTrack _route({String? diveId, String? siteId}) => NavTrack(
  id: 'r1',
  diveId: diveId,
  siteId: siteId,
  linkMode: diveId == null ? null : NavTrackLinkMode.auto,
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 10,
  points: _points(),
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Future<_RecordingNavTrackRepository> _pump(
  WidgetTester tester, {
  required NavTrack route,
  Dive? linkedDive,
  DiveSite? site,
  Override? bathymetryOverride,
}) async {
  final overrides = await getBaseOverrides();
  final repository = _RecordingNavTrackRepository();
  final router = GoRouter(
    initialLocation: '/nav-routes/${route.id}',
    routes: [
      GoRoute(
        path: '/nav-routes/:id',
        builder: (context, state) =>
            const Scaffold(body: Text('ROUTE_DETAIL_PAGE')),
      ),
      GoRoute(
        path: '/nav-routes/:id/align',
        builder: (context, state) =>
            NavTrackAlignPage(routeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/nav-routes/:id/3d',
        builder: (context, state) =>
            const Scaffold(body: Text('ROUTE_3D_PAGE')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        navTrackByIdProvider(route.id).overrideWith((ref) async => route),
        navTrackRepositoryProvider.overrideWithValue(repository),
        if (linkedDive != null)
          diveProvider(linkedDive.id).overrideWith((ref) async => linkedDive),
        if (site != null)
          siteProvider(site.id).overrideWith((ref) async => site),
        // Never hit the real bathymetry cache/network from a widget test.
        bathymetryOverride ??
            bathymetryGridProvider.overrideWith((ref, cell) async => null),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  router.push('/nav-routes/${route.id}/align');
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets(
    'setting a start point on the map and saving persists the anchor',
    (tester) async {
      final repository = await _pump(tester, route: _route());

      await tester.tap(
        find.byKey(const ValueKey('nav-track-align-place-start')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nav-track-align-set-here')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      expect(repository.lastRouteId, 'r1');
      expect(repository.lastCorrection?.anchor, isNotNull);
    },
  );

  testWidgets(
    'the "From dive entry" chip sets the anchor from the linked dive',
    (tester) async {
      final dive = Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 8, 22, 10, 8),
        entryLocation: const GeoPoint(46.9, 7.2),
      );
      final repository = await _pump(
        tester,
        route: _route(diveId: 'dive-1'),
        linkedDive: dive,
      );

      expect(
        find.byKey(const ValueKey('nav-track-align-from-dive-entry')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('nav-track-align-from-dive-entry')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      expect(repository.lastCorrection?.anchor, const GeoPoint(46.9, 7.2));
    },
  );

  testWidgets('the "From site" chip sets the anchor from the route\'s site', (
    tester,
  ) async {
    const site = DiveSite(
      id: 'site-1',
      name: 'Test Site',
      location: GeoPoint(47.1, 8.3),
    );
    final repository = await _pump(
      tester,
      route: _route(siteId: 'site-1'),
      site: site,
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-align-from-site')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
    await tester.pumpAndSettle();

    expect(repository.lastCorrection?.anchor, const GeoPoint(47.1, 8.3));
  });

  testWidgets(
    'the "From site" chip still works after other controls triggered a '
    'rebuild (regression: the chip used to sit behind a FutureBuilder '
    'whose Future was recreated on every setState, one Flutter anti-'
    'pattern independent of whether it ever visibly broke the chip)',
    (tester) async {
      const site = DiveSite(
        id: 'site-1',
        name: 'Test Site',
        location: GeoPoint(47.1, 8.3),
      );
      final repository = await _pump(
        tester,
        route: _route(siteId: 'site-1'),
        site: site,
      );

      // Trigger a handful of rebuilds via setState before using the chip.
      final sliderFinder = find.byKey(
        const ValueKey('nav-track-align-trust-slider'),
      );
      await tester.drag(sliderFinder, const Offset(20, 0));
      await tester.pump();
      await tester.drag(sliderFinder, const Offset(-10, 0));
      await tester.pump();

      final chipFinder = find.byKey(
        const ValueKey('nav-track-align-from-site'),
      );
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      expect(repository.lastCorrection?.anchor, const GeoPoint(47.1, 8.3));
    },
  );

  testWidgets(
    'the "From GPS" chip appears for a route with a pre-dive fix and sets '
    'the anchor from the site pin, back-solved through the fix (item 3)',
    (tester) async {
      const site = DiveSite(
        id: 'site-1',
        name: 'Test Site',
        location: GeoPoint(47.1, 8.3),
      );
      final preDiveFixPoints = [
        const NavTrackPoint(timestamp: 1755856800, north: 0, east: 0, depth: 0),
        // A pre-dive GPS re-calibration jump, before any underwater sample.
        const NavTrackPoint(
          timestamp: 1755856802,
          north: 100,
          east: 0,
          depth: 0,
        ),
        const NavTrackPoint(
          timestamp: 1755856804,
          north: 100,
          east: 0,
          depth: 0,
        ),
        // Now descending: ends the fixed run.
        const NavTrackPoint(
          timestamp: 1755856806,
          north: 100,
          east: 0,
          depth: 5,
        ),
        const NavTrackPoint(
          timestamp: 1755856808,
          north: 105,
          east: 2,
          depth: 8,
        ),
      ];
      final route = NavTrack(
        id: 'r1',
        siteId: 'site-1',
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'r1.csv',
        startTime: 1755856800000,
        endTime: 1755856808000,
        pointCount: preDiveFixPoints.length,
        points: preDiveFixPoints,
        createdAt: DateTime(2026, 8, 22),
        updatedAt: DateTime(2026, 8, 22),
      );

      final repository = await _pump(tester, route: route, site: site);

      final chipFinder = find.byKey(const ValueKey('nav-track-align-from-gps'));
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      final anchor = repository.lastCorrection?.anchor;
      expect(anchor, isNotNull);
      // The stabilized fix position is (north: 100, east: 0), so the
      // suggested anchor is the site pin shifted 100 m back (south) --
      // definitely not the site pin itself.
      expect(anchor, isNot(site.location));
      final backToFix = offsetToGeoPoint(anchor!, east: 0, north: 100);
      expect(backToFix.latitude, closeTo(site.location!.latitude, 1e-6));
      expect(backToFix.longitude, closeTo(site.location!.longitude, 1e-6));
    },
  );

  testWidgets(
    'the "From GPS" chip does not appear for a route with no pre-dive fix',
    (tester) async {
      const site = DiveSite(
        id: 'site-1',
        name: 'Test Site',
        location: GeoPoint(47.1, 8.3),
      );
      await _pump(
        tester,
        route: _route(siteId: 'site-1'),
        site: site,
      );

      expect(
        find.byKey(const ValueKey('nav-track-align-from-gps')),
        findsNothing,
      );
    },
  );

  testWidgets('the end mode dropdown switches to "same as start"', (
    tester,
  ) async {
    final repository = await _pump(tester, route: _route());

    await tester.tap(find.byKey(const ValueKey('nav-track-align-end-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same as start').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
    await tester.pumpAndSettle();

    expect(repository.lastCorrection?.endMode, NavTrackEndMode.sameAsStart);
  });

  testWidgets(
    'dragging the trust slider updates the trust fraction and readout',
    (tester) async {
      final repository = await _pump(tester, route: _route());

      final sliderFinder = find.byKey(
        const ValueKey('nav-track-align-trust-slider'),
      );
      expect(sliderFinder, findsOneWidget);

      await tester.drag(sliderFinder, const Offset(80, 0));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      expect(repository.lastCorrection?.trustFraction, greaterThan(0));
    },
  );

  testWidgets('moving the trust slider moves the trust marker on the route', (
    tester,
  ) async {
    await _pump(tester, route: _route());

    // Place the start marker so the route (and the trust marker) renders.
    await tester.tap(find.byKey(const ValueKey('nav-track-align-place-start')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-track-align-set-here')));
    await tester.pump();

    final trustMarkerFinder = find.byKey(
      const ValueKey('nav-track-align-trust-marker'),
    );
    expect(trustMarkerFinder, findsOneWidget);
    final before = tester.getCenter(trustMarkerFinder);

    final sliderFinder = find.byKey(
      const ValueKey('nav-track-align-trust-slider'),
    );
    await tester.drag(sliderFinder, const Offset(150, 0));
    await tester.pump();

    final after = tester.getCenter(trustMarkerFinder);
    expect(after, isNot(before));
  });

  testWidgets('reset correction clears the anchor and end mode', (
    tester,
  ) async {
    final repository = await _pump(tester, route: _route());

    await tester.tap(find.byKey(const ValueKey('nav-track-align-place-start')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-track-align-set-here')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('nav-track-align-reset')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
    await tester.pumpAndSettle();

    expect(repository.lastCorrection?.anchor, isNull);
    expect(repository.lastCorrection?.endMode, NavTrackEndMode.none);
    expect(repository.lastCorrection?.trustFraction, 0);
  });

  testWidgets(
    'dragging the start marker right on screen moves it east, and down '
    'moves it south',
    (tester) async {
      final repository = await _pump(tester, route: _route());

      // Place the start marker at the map's initial centre first.
      await tester.tap(
        find.byKey(const ValueKey('nav-track-align-place-start')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nav-track-align-set-here')));
      await tester.pump();

      final markerFinder = find.byKey(
        const ValueKey('nav-track-align-start-marker'),
      );
      expect(markerFinder, findsOneWidget);

      // Drag right and down on screen.
      await tester.drag(markerFinder, const Offset(40, 30));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      const before = GeoPoint(0, 0);
      final after = repository.lastCorrection?.anchor;
      expect(after, isNotNull);
      // Right on screen must increase longitude (east); down must decrease
      // latitude (south). A north/east or sign mix-up would flip one or
      // both of these compass directions.
      expect(after!.longitude, greaterThan(before.longitude));
      expect(after.latitude, lessThan(before.latitude));
    },
  );

  testWidgets(
    'shows a "Start:" heading above the start-point actions, mirroring '
    'the "End:" heading above the end-mode dropdown (item 2)',
    (tester) async {
      await _pump(tester, route: _route());

      expect(find.text('Start: '), findsOneWidget);
      expect(find.text('End: '), findsOneWidget);
    },
  );

  testWidgets('cancel pops without saving', (tester) async {
    final repository = await _pump(tester, route: _route());

    await tester.tap(find.byKey(const ValueKey('nav-track-align-cancel')));
    await tester.pumpAndSettle();

    expect(repository.lastCorrection, isNull);
  });

  testWidgets(
    '"Open 3D" saves the in-progress correction before navigating, so the '
    '3D view (which reloads the route from the repository) reflects what '
    'is currently being edited rather than the last-saved state (item 22)',
    (tester) async {
      final repository = await _pump(tester, route: _route());

      await tester.tap(
        find.byKey(const ValueKey('nav-track-align-place-start')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-track-align-set-here')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-3d')));
      await tester.pumpAndSettle();

      expect(repository.lastRouteId, 'r1');
      expect(repository.lastCorrection, isNotNull);
      expect(find.text('ROUTE_3D_PAGE'), findsOneWidget);
    },
  );

  testWidgets(
    'typing a rotation value into the field updates headingOffsetDeg',
    (tester) async {
      final repository = await _pump(tester, route: _route());

      final fieldFinder = find.byKey(
        const ValueKey('nav-track-align-rotation-field'),
      );
      await tester.enterText(fieldFinder, '12.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      expect(repository.lastCorrection?.headingOffsetDeg, 12.5);
    },
  );

  testWidgets(
    'entering garbage text into the rotation field leaves the prior value '
    'intact',
    (tester) async {
      final repository = await _pump(tester, route: _route());

      // Establish a known non-zero value first via the stepper.
      await tester.tap(find.byKey(const ValueKey('nav-track-align-rotate-up')));
      await tester.pump();

      final fieldFinder = find.byKey(
        const ValueKey('nav-track-align-rotation-field'),
      );
      await tester.enterText(fieldFinder, 'not a number');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('nav-track-align-save')));
      await tester.pumpAndSettle();

      expect(repository.lastCorrection?.headingOffsetDeg, 0.5);
    },
  );

  testWidgets(
    'discards a stale terrain-check result that resolves after a newer one '
    '(item 6): moving the start point twice must not let the FIRST, '
    'slower bathymetry fetch overwrite the SECOND, faster one that already '
    'landed',
    (tester) async {
      final completers =
          <({double lat, double lon}), Completer<BathymetryGrid?>>{};
      final grid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 0.01,
        cellSizeLonDeg: 0.01,
        rows: 1,
        cols: 1,
        depthsMeters: const [50.0],
        sourceId: 'test',
        resolutionMeters: 5, // fine: no "coarse bathymetry" caveat
        fetchedAt: DateTime(2026, 1, 1),
      );
      final coarseGrid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 0.01,
        cellSizeLonDeg: 0.01,
        rows: 1,
        cols: 1,
        depthsMeters: const [50.0],
        sourceId: 'test-coarse',
        resolutionMeters: 500, // coarse: adds the caveat
        fetchedAt: DateTime(2026, 1, 1),
      );

      final dive = Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 8, 22, 10, 8),
        entryLocation: const GeoPoint(46.9, 7.2),
      );
      await _pump(
        tester,
        route: _route(diveId: 'dive-1'),
        linkedDive: dive,
        bathymetryOverride: bathymetryGridProvider.overrideWith((ref, cell) {
          final completer = completers.putIfAbsent(cell, () => Completer());
          return completer.future;
        }),
      );

      // First terrain check: the start point at the map's initial centre
      // (0, 0) -- a different quantized cell from the dive entry below.
      await tester.tap(
        find.byKey(const ValueKey('nav-track-align-place-start')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nav-track-align-set-here')));
      await tester.pump(const Duration(milliseconds: 300)); // debounce fires
      final firstCell = completers.keys.single;

      // Before the first fetch resolves, move the start point again (a
      // different cell): the second, later terrain check must supersede it.
      await tester.tap(
        find.byKey(const ValueKey('nav-track-align-from-dive-entry')),
      );
      await tester.pump(const Duration(milliseconds: 300)); // debounce fires
      expect(completers.length, 2);
      final secondCell = completers.keys.firstWhere((c) => c != firstCell);

      // The second (newer) request resolves first, with the fine grid.
      completers[secondCell]!.complete(grid);
      await tester.pump();
      expect(find.textContaining('coarse bathymetry'), findsNothing);

      // The first (older, slower) request resolves last, with a coarse
      // grid. It must be discarded, not overwrite the newer result.
      completers[firstCell]!.complete(coarseGrid);
      await tester.pump();

      expect(find.textContaining('coarse bathymetry'), findsNothing);
    },
  );

  testWidgets(
    'the terrain check only runs over the active dead-reckoned range, not '
    'the raw recording (proactive finding: a GPS-fixed/out-of-water tail '
    'must not be checked against the seafloor at all)',
    (tester) async {
      final grid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 0.05,
        cellSizeLonDeg: 0.05,
        rows: 1,
        cols: 1,
        depthsMeters: const [50.0],
        sourceId: 'test',
        resolutionMeters: 5,
        fetchedAt: DateTime(2026, 1, 1),
      );

      final route = NavTrack(
        id: 'r-fix',
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'r-fix.csv',
        startTime: 0,
        endTime: 20000,
        pointCount: 4,
        anchorLatitude: 0,
        anchorLongitude: 0,
        points: const [
          NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 5),
          NavTrackPoint(
            timestamp: 10,
            north: 5,
            east: 0,
            depth: 0.1,
            distance: 5,
          ),
          // Fix event: >50 m step in <=5 s at the surface -- excluded from
          // the active range from here on.
          NavTrackPoint(
            timestamp: 12,
            north: 400,
            east: 0,
            depth: 0.1,
            distance: 5,
          ),
          NavTrackPoint(
            timestamp: 20,
            north: 405,
            east: 0,
            depth: 0.1,
            distance: 5,
          ),
        ],
        createdAt: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

      await _pump(
        tester,
        route: route,
        bathymetryOverride: bathymetryGridProvider.overrideWith(
          (ref, cell) async => grid,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300)); // debounce fires
      await tester.pump();

      // Only the 2 pre-fix samples may be checked, never all 4 raw ones.
      expect(find.textContaining('of 2 below the seafloor'), findsOneWidget);
      expect(find.textContaining('of 4 below the seafloor'), findsNothing);
    },
  );

  testWidgets(
    'the trust slider shares the corrector\'s device-distance-channel '
    'preference instead of always recomputing geometric path length '
    '(item 2)',
    (tester) async {
      final points = [
        const NavTrackPoint(
          timestamp: 0,
          north: 0,
          east: 0,
          depth: 5,
          distance: 0,
        ),
        const NavTrackPoint(
          timestamp: 10,
          north: 10,
          east: 0,
          depth: 5,
          distance: 10,
        ),
        // Loops back to the previous position -- geometric path length adds
        // almost nothing here -- while the device's own distance channel
        // (integrated from the speed log, not from position) keeps
        // climbing, exactly the ENC console shape the design spec
        // describes.
        const NavTrackPoint(
          timestamp: 20,
          north: 10,
          east: 0,
          depth: 5,
          distance: 1000,
        ),
      ];
      final route = NavTrack(
        id: 'r-loop',
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'loop.csv',
        startTime: 0,
        endTime: 20000,
        pointCount: points.length,
        points: points,
        createdAt: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

      await _pump(tester, route: route);

      final sliderFinder = find.byKey(
        const ValueKey('nav-track-align-trust-slider'),
      );
      // Drag far enough right to saturate the trust fraction near 1.0.
      await tester.drag(sliderFinder, const Offset(2000, 0));
      await tester.pump();

      // Geometric path length over these 3 samples is only 10 m (the loop
      // back to the same position contributes nothing); the device
      // distance channel reaches 1000 m. A slider that recomputed
      // geometric path length instead of sharing the corrector's own
      // distance-source rule could never show more than ~10 m here.
      expect(find.textContaining('trusted up to 10 m'), findsNothing);
      expect(
        find.textContaining(RegExp(r'trusted up to (9\d\d|1000) m')),
        findsOneWidget,
      );
    },
  );

  group('GPS-fix dots stay put under rotation and trust (item 1)', () {
    // The real fixture with a genuine surface GPS fix event (011.DAT.csv,
    // spec "A surface GPS fix inside the same file"): the yellow dots must
    // render from the raw recording, never from NavTrackCorrector.apply,
    // so neither headingOffsetDeg nor trustFraction may move them.
    final track = parseSeacraftEncCsv(
      File(
        'test/fixtures/nav_tracks/seacraft_enc3_gps_fix.csv',
      ).readAsBytesSync(),
    );

    NavTrack fixRoute() => NavTrack(
      id: 'r-fix',
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'fix.csv',
      startTime: track.points.first.timestamp * 1000,
      endTime: track.points.last.timestamp * 1000,
      pointCount: track.points.length,
      points: track.points,
      anchorLatitude: 47.1,
      anchorLongitude: 8.3,
      createdAt: DateTime(2026, 9, 6),
      updatedAt: DateTime(2026, 9, 6),
    );

    LatLng firstGpsFixDotPosition(WidgetTester tester) {
      final markerLayers = tester
          .widgetList<MarkerLayer>(find.byType(MarkerLayer))
          .where(
            (layer) => layer.markers.any((m) => m.width == 6 && m.height == 6),
          )
          .toList();
      expect(
        markerLayers,
        isNotEmpty,
        reason: 'expected a GPS-fix dots layer to be rendered',
      );
      return markerLayers.first.markers.first.point;
    }

    testWidgets('changing headingOffsetDeg does not move a GPS-fix dot', (
      tester,
    ) async {
      await _pump(tester, route: fixRoute());

      final before = firstGpsFixDotPosition(tester);

      await tester.tap(find.byKey(const ValueKey('nav-track-align-rotate-up')));
      await tester.pump();
      // A single 0.5 degree step barely moves anything; use a large,
      // unambiguous rotation instead.
      final fieldFinder = find.byKey(
        const ValueKey('nav-track-align-rotation-field'),
      );
      await tester.enterText(fieldFinder, '90');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final after = firstGpsFixDotPosition(tester);

      expect(after.latitude, closeTo(before.latitude, 1e-9));
      expect(after.longitude, closeTo(before.longitude, 1e-9));
    });

    testWidgets('changing trustFraction does not move a GPS-fix dot', (
      tester,
    ) async {
      await _pump(tester, route: fixRoute());

      final before = firstGpsFixDotPosition(tester);

      await tester.drag(
        find.byKey(const ValueKey('nav-track-align-trust-slider')),
        const Offset(120, 0),
      );
      await tester.pump();

      final after = firstGpsFixDotPosition(tester);

      expect(after.latitude, closeTo(before.latitude, 1e-9));
      expect(after.longitude, closeTo(before.longitude, 1e-9));
    });
  });
}
