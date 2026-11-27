import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_fields.dart';
import 'package:submersion/features/nav_track/application/nav_track_scene_providers.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_align_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_seascape_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_preview_provider.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';

import '../../../../helpers/mock_providers.dart';

/// The align page follows the track's lock behind the phase 3 switch
/// (issue #4527, plan 5): it only reads unless the track page's sitting is
/// handed to it, and then Done hands the correction to that sitting.
class _RecordingNavTrackRepository extends NavTrackRepository {
  final corrections = <NavTrackCorrection>[];

  @override
  Future<void> updateCorrection(
    String routeId,
    NavTrackCorrection correction,
  ) async => corrections.add(correction);
}

final _route = NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 10,
  anchorLatitude: 28.5,
  anchorLongitude: 34.5,
  points: [
    for (var i = 0; i < 10; i++)
      NavTrackPoint(
        timestamp: 1755856800 + i * 10,
        north: i * 10.0,
        east: i * 5.0,
        depth: 5.0 + i,
        distance: i * 11.0,
      ),
  ],
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

/// A route whose recording ends where it started, with no end correction
/// stored: the align page proposes "same as start" for it.
final _loop = NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 11,
  anchorLatitude: 28.5,
  anchorLongitude: 34.5,
  points: [
    for (var i = 0; i <= 10; i++)
      NavTrackPoint(
        timestamp: 1755856800 + i * 10,
        north: (i <= 5 ? i : 10 - i) * 10.0,
        east: 0,
        depth: 6,
        distance: i * 10.0,
      ),
  ],
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

/// A sitting on [_route], as the track page would hand it.
RecordEditController<NavTrack> _sitting() {
  final controller = RecordEditController<NavTrack>(onSave: (_) async {});
  addTearDown(controller.dispose);
  controller.unlock(_route);
  return controller;
}

Future<_RecordingNavTrackRepository> _pump(
  WidgetTester tester, {
  RecordEditController<NavTrack>? joined,
  NavTrack? route,
}) async {
  final overrides = await getBaseOverrides();
  final repository = _RecordingNavTrackRepository();
  final router = GoRouter(
    initialLocation: '/tracks/underwater/r1',
    routes: [
      GoRoute(
        path: '/tracks/underwater/:id',
        builder: (context, state) =>
            const Scaffold(body: Text('ROUTE_DETAIL_PAGE')),
      ),
      GoRoute(
        path: '/tracks/underwater/:id/align',
        builder: (context, state) => NavTrackAlignPage(
          routeId: state.pathParameters['id']!,
          joinedSitting: joined,
        ),
      ),
      GoRoute(
        path: '/tracks/underwater/:id/3d',
        builder: (context, state) =>
            const Scaffold(body: Text('ROUTE_3D_PAGE')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        navTrackByIdProvider('r1').overrideWith((ref) async => route ?? _route),
        navTrackRepositoryProvider.overrideWithValue(repository),
        bathymetryGridProvider.overrideWith((ref, cell) async => null),
        navTrackSceneProvider('r1').overrideWith((ref) async => null),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  router.push('/tracks/underwater/r1/align');
  await tester.pumpAndSettle();
  return repository;
}

final _slider = find.byKey(const ValueKey('nav-track-align-trust-slider'));

void main() {
  testWidgets('locked, the controls are off and nothing is written', (
    tester,
  ) async {
    final repository = await _pump(tester);

    final controls = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('nav-track-align-controls')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(controls.ignoring, isTrue);
    expect(find.byKey(const ValueKey('nav-track-align-save')), findsNothing);
    expect(find.byKey(const ValueKey('nav-track-align-done')), findsNothing);
    expect(find.byKey(const ValueKey('nav-track-align-reset')), findsNothing);
    await tester.drag(_slider, const Offset(80, 0), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Slider>(_slider).value,
      0,
      reason: 'the trust slider did not move',
    );
    expect(repository.corrections, isEmpty);
  });

  testWidgets('read only, the 3D button writes nothing', (tester) async {
    final repository = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('nav-track-align-3d')));
    await tester.pumpAndSettle();

    expect(find.byType(NavTrackSeascapePage), findsOneWidget);
    expect(repository.corrections, isEmpty);
  });

  testWidgets("joined, it starts from the sitting's correction", (
    tester,
  ) async {
    final sitting = _sitting();
    setNavTrackCorrection(
      sitting.session!,
      const NavTrackCorrection(anchor: GeoPoint(1, 2), scaleFactor: 2),
    );
    await _pump(tester, joined: sitting);

    // Done with no change keeps what the sitting held.
    await tester.tap(find.byKey(const ValueKey('nav-track-align-done')));
    await tester.pumpAndSettle();

    final correction = navTrackCorrectionIn(sitting.session!);
    expect(correction.anchor, const GeoPoint(1, 2));
    expect(correction.scaleFactor, 2);
  });

  testWidgets('Done hands the correction to the sitting and writes nothing', (
    tester,
  ) async {
    final sitting = _sitting();
    final repository = await _pump(tester, joined: sitting);

    await tester.drag(_slider, const Offset(80, 0));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-track-align-done')));
    await tester.pumpAndSettle();

    expect(find.text('ROUTE_DETAIL_PAGE'), findsOneWidget);
    expect(repository.corrections, isEmpty);
    expect(sitting.session!.changedCardIds, {'correction'});
    expect(
      navTrackCorrectionIn(sitting.session!).trustFraction,
      greaterThan(0),
    );
  });

  testWidgets("Done, then the track's Cancel, leaves the correction stored", (
    tester,
  ) async {
    final sitting = _sitting();
    final repository = await _pump(tester, joined: sitting);
    await tester.drag(_slider, const Offset(80, 0));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-track-align-done')));
    await tester.pumpAndSettle();

    sitting.lock();
    await tester.pumpAndSettle();

    expect(sitting.session, isNull);
    expect(repository.corrections, isEmpty);
  });

  testWidgets("the align page's Cancel leaves the sitting's correction", (
    tester,
  ) async {
    final sitting = _sitting();
    await _pump(tester, joined: sitting);

    await tester.drag(_slider, const Offset(80, 0));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-track-align-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('ROUTE_DETAIL_PAGE'), findsOneWidget);
    expect(sitting.session!.changedCardIds, isEmpty);
  });

  testWidgets("the 3D button previews the page's correction and writes "
      'nothing', (tester) async {
    final sitting = _sitting();
    final repository = await _pump(tester, joined: sitting);
    await tester.drag(_slider, const Offset(80, 0));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavTrackAlignPage)),
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-align-3d')));
    await tester.pumpAndSettle();

    expect(find.byType(NavTrackSeascapePage), findsOneWidget);
    expect(
      container.read(navTrackPreviewProvider('r1'))?.trustFraction,
      greaterThan(0),
    );
    expect(repository.corrections, isEmpty);
    expect(sitting.session!.changedCardIds, isEmpty);
  });

  testWidgets('a sitting that ends underneath leaves the page reading only', (
    tester,
  ) async {
    final sitting = _sitting();
    await _pump(tester, joined: sitting);
    expect(find.byKey(const ValueKey('nav-track-align-done')), findsOneWidget);

    sitting.lock();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nav-track-align-done')), findsNothing);
    expect(find.byKey(const ValueKey('nav-track-align-save')), findsNothing);
  });

  NavTrackEndMode drawnEndMode(WidgetTester tester) => tester
      .widget<NavTrackPolylineLayer>(find.byType(NavTrackPolylineLayer))
      .route
      .endMode;

  testWidgets('read only, it draws the stored alignment, not its suggestion', (
    tester,
  ) async {
    await _pump(tester, route: _loop);

    expect(drawnEndMode(tester), NavTrackEndMode.none);
  });

  testWidgets('joined, it still proposes "same as start"', (tester) async {
    final controller = RecordEditController<NavTrack>(onSave: (_) async {});
    addTearDown(controller.dispose);
    controller.unlock(_loop);
    await _pump(tester, joined: controller, route: _loop);

    expect(drawnEndMode(tester), NavTrackEndMode.sameAsStart);
  });

  testWidgets('a sitting that ends underneath drops the tweaks made here', (
    tester,
  ) async {
    final sitting = _sitting();
    await _pump(tester, joined: sitting);
    await tester.drag(_slider, const Offset(80, 0));
    await tester.pump();
    expect(tester.widget<Slider>(_slider).value, greaterThan(0));

    sitting.lock();
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(_slider).value, 0);
  });

  testWidgets('pushed over the shell, its 3D button opens the seascape on '
      'top of it', (tester) async {
    final overrides = await getBaseOverrides();
    final sitting = _sitting();
    final router = GoRouter(
      initialLocation: '/tracks/underwater/r1',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/tracks/underwater/:id',
              builder: (context, state) => Builder(
                builder: (context) => TextButton(
                  onPressed: () => pushRecordSatellite<NavTrack, void>(
                    context,
                    sitting: sitting,
                    builder: (joined) =>
                        NavTrackAlignPage(routeId: 'r1', joinedSitting: joined),
                  ),
                  child: const Text('open align'),
                ),
              ),
            ),
            GoRoute(
              path: '/tracks/underwater/:id/3d',
              builder: (context, state) =>
                  const Scaffold(body: Text('ROUTE_3D_PAGE')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          navTrackByIdProvider('r1').overrideWith((ref) async => _route),
          bathymetryGridProvider.overrideWith((ref, cell) async => null),
          navTrackSceneProvider('r1').overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open align'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-track-align-3d')));
    await tester.pumpAndSettle();

    expect(find.byType(NavTrackSeascapePage).hitTestable(), findsOneWidget);
  });

  testWidgets("joined, the 3D preview carries the sitting's held site", (
    tester,
  ) async {
    final sitting = _sitting();
    sitting.session!.set(navTrackSiteField, 's2');
    await _pump(tester, joined: sitting);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavTrackAlignPage)),
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-align-3d')));
    await tester.pumpAndSettle();

    expect(container.read(navTrackPreviewProvider('r1'))?.siteId, 's2');
  });
}
