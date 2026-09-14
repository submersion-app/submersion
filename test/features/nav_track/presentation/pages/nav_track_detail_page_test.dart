import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_detail_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records calls instead of touching a real database, mirroring the
/// alignment page test's `_RecordingNavTrackRepository`.
class _RecordingNavTrackRepository extends NavTrackRepository {
  String? renamedId;
  String? newName;
  String? unlinkedId;
  String? deletedId;
  String? linkedRouteId;
  String? linkedDiveId;
  NavTrackLinkMode? linkMode;

  @override
  Future<void> rename(String routeId, String? name) async {
    renamedId = routeId;
    newName = name;
  }

  @override
  Future<void> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    linkedRouteId = routeId;
    linkedDiveId = diveId;
    this.linkMode = linkMode;
  }

  @override
  Future<void> unlink(String routeId) async {
    unlinkedId = routeId;
  }

  @override
  Future<void> delete(String routeId) async {
    deletedId = routeId;
  }
}

NavTrack _route({
  String? diveId,
  String? equipmentId,
  String? siteId,
  double? anchorLatitude,
  double? anchorLongitude,
  NavTrackEndMode endMode = NavTrackEndMode.none,
}) => NavTrack(
  id: 'r1',
  diveId: diveId,
  equipmentId: equipmentId,
  siteId: siteId,
  linkMode: diveId == null ? null : NavTrackLinkMode.auto,
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 0,
  anchorLatitude: anchorLatitude,
  anchorLongitude: anchorLongitude,
  endMode: endMode,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Future<_RecordingNavTrackRepository> _pump(
  WidgetTester tester, {
  required NavTrack route,
  Dive? linkedDive,
  EquipmentItem? equipment,
  DiveSite? site,
  GoRouter? router,
  List<Dive>? allDives,
}) async {
  final overrides = await getBaseOverrides();
  final repository = _RecordingNavTrackRepository();
  final effectiveOverrides = [
    ...overrides,
    navTrackByIdProvider(route.id).overrideWith((ref) async => route),
    navTrackRepositoryProvider.overrideWithValue(repository),
    if (linkedDive != null)
      diveProvider(linkedDive.id).overrideWith((ref) async => linkedDive),
    if (equipment != null)
      equipmentItemProvider(
        equipment.id,
      ).overrideWith((ref) async => equipment),
    if (site != null) siteProvider(site.id).overrideWith((ref) async => site),
    if (allDives != null) divesProvider.overrideWith((ref) async => allDives),
  ];
  if (router != null) {
    await tester.pumpWidget(
      ProviderScope(
        overrides: effectiveOverrides,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  } else {
    await tester.pumpWidget(
      ProviderScope(
        overrides: effectiveOverrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: route.id),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('shows "No dive linked" for an unlinked route', (tester) async {
    await _pump(tester, route: _route());

    expect(find.byKey(const ValueKey('nav-track-no-dive')), findsOneWidget);
    expect(find.text('No dive linked'), findsOneWidget);
    expect(find.text('Choose dive'), findsOneWidget);
  });

  testWidgets('shows the linked dive for a linked route', (tester) async {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 412,
      dateTime: DateTime(2026, 8, 22, 10, 8),
    );
    await _pump(
      tester,
      route: _route(diveId: 'dive-1'),
      linkedDive: dive,
    );

    expect(find.byKey(const ValueKey('nav-track-linked-dive')), findsOneWidget);
    expect(find.textContaining('#412'), findsOneWidget);
  });

  testWidgets('tapping "Choose dive" and picking one links the route to it', (
    tester,
  ) async {
    final candidate = Dive(
      id: 'dive-9',
      diveNumber: 9,
      dateTime: DateTime(2026, 8, 22, 9),
      entryTime: DateTime(2026, 8, 22, 9),
    );
    final repository = await _pump(
      tester,
      route: _route(),
      allDives: [candidate],
    );

    await tester.tap(find.text('Choose dive'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#9'));
    await tester.pumpAndSettle();

    expect(repository.linkedRouteId, 'r1');
    expect(repository.linkedDiveId, 'dive-9');
    expect(repository.linkMode, NavTrackLinkMode.manual);
  });

  testWidgets('shows the no-correction sentence when nothing was aligned', (
    tester,
  ) async {
    await _pump(tester, route: _route());

    expect(find.text('No correction applied yet.'), findsOneWidget);
  });

  testWidgets('shows the linked equipment name when equipmentId is set', (
    tester,
  ) async {
    const scooter = EquipmentItem(
      id: 'eq1',
      name: 'Test Scooter',
      type: EquipmentType.dpv,
    );
    await _pump(
      tester,
      route: _route(equipmentId: 'eq1'),
      equipment: scooter,
    );

    expect(find.text('Equipment: Test Scooter'), findsOneWidget);
  });

  testWidgets('shows no equipment line when equipmentId is not set', (
    tester,
  ) async {
    await _pump(tester, route: _route());

    expect(find.textContaining('Equipment:'), findsNothing);
  });

  testWidgets(
    'the inline map preview renders a TileLayer with the app\'s tile URL '
    '(item 3)',
    (tester) async {
      await _pump(
        tester,
        route: _route(anchorLatitude: 47.1, anchorLongitude: 8.3),
      );

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NavTrackDetailPage)),
      );
      expect(tileLayer.urlTemplate, container.read(mapTileUrlProvider));
    },
  );

  group('the site row (item 4)', () {
    testWidgets(
      'shows a "no site" placeholder and "Choose site" when unset, and no '
      'longer offers "Change site" from the overflow menu',
      (tester) async {
        await _pump(tester, route: _route());

        expect(
          find.byKey(const ValueKey('nav-track-site-row')),
          findsOneWidget,
        );
        expect(find.text('No site'), findsOneWidget);
        expect(find.text('Choose site'), findsOneWidget);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Change site'), findsNothing);
      },
    );

    testWidgets('shows the site name and "Change site" when a site is set', (
      tester,
    ) async {
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

      expect(find.byKey(const ValueKey('nav-track-site-row')), findsOneWidget);
      expect(find.text('Test Site'), findsOneWidget);
      expect(find.text('Change site'), findsOneWidget);
    });

    testWidgets('tapping the action opens the site picker', (tester) async {
      await _pump(tester, route: _route());

      await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
      await tester.pumpAndSettle();

      expect(find.byType(SitePickerSheet), findsOneWidget);
    });
  });

  testWidgets('shows a loading indicator while the route resolves', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final completer = Completer<NavTrack?>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(null);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          navTrackByIdProvider('r1').overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: 'r1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('shows the load-error message when the provider errors', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          navTrackByIdProvider(
            'r1',
          ).overrideWith((ref) async => Future<NavTrack?>.error('boom')),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: 'r1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this route.'), findsOneWidget);
  });

  testWidgets('shows "Route not found" when the route no longer exists', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          navTrackByIdProvider('r1').overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: 'r1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Route not found.'), findsOneWidget);
  });

  testWidgets('shows the "set start point" placeholder when unanchored', (
    tester,
  ) async {
    await _pump(tester, route: _route());

    expect(
      find.text('Set the start point to see this on a map.'),
      findsOneWidget,
    );
    expect(find.byType(FlutterMap), findsNothing);
  });

  group('correction status text per end mode', () {
    testWidgets('none', (tester) async {
      await _pump(tester, route: _route());
      expect(find.text('No correction applied yet.'), findsOneWidget);
    });

    testWidgets('sameAsStart', (tester) async {
      await _pump(tester, route: _route(endMode: NavTrackEndMode.sameAsStart));
      expect(find.text('End set to same as start.'), findsOneWidget);
    });

    testWidgets('point', (tester) async {
      await _pump(tester, route: _route(endMode: NavTrackEndMode.point));
      expect(find.text('End point set on the map.'), findsOneWidget);
    });

    testWidgets('gpsFix', (tester) async {
      await _pump(tester, route: _route(endMode: NavTrackEndMode.gpsFix));
      expect(
        find.text('End set from the recording\'s GPS fix.'),
        findsOneWidget,
      );
    });
  });

  group('overflow menu actions', () {
    testWidgets('rename saves the trimmed new name through the repository', (
      tester,
    ) async {
      final repository = await _pump(tester, route: _route());

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Morning dive  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.renamedId, 'r1');
      expect(repository.newName, 'Morning dive');
    });

    testWidgets('the unlink item only appears for a linked route, and calls '
        'unlink', (tester) async {
      final unlinkedRepository = await _pump(
        tester,
        route: _route(diveId: 'dive-1'),
        linkedDive: Dive(
          id: 'dive-1',
          diveNumber: 5,
          dateTime: DateTime(2026, 8, 22),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Unlink'), findsOneWidget);
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(unlinkedRepository.unlinkedId, 'r1');
    });

    testWidgets('no unlink item for an unlinked route', (tester) async {
      await _pump(tester, route: _route());

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Unlink'), findsNothing);
    });

    testWidgets('delete asks for confirmation, then deletes and pops', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final repository = _RecordingNavTrackRepository();
      final route = _route();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/nav-routes/${route.id}'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: '/nav-routes/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider(route.id).overrideWith((ref) async => route),
            navTrackRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete route?'), findsOneWidget);
      // Two "Delete" texts now exist: the dialog title's button and the
      // menu item underneath; tap the dialog's action explicitly.
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deletedId, 'r1');
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('toolbar navigation', () {
    testWidgets('the align button pushes the alignment route', (tester) async {
      final overrides = await getBaseOverrides();
      final route = _route();
      final router = GoRouter(
        initialLocation: '/nav-routes/${route.id}',
        routes: [
          GoRoute(
            path: '/nav-routes/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/nav-routes/:id/align',
            builder: (context, state) =>
                const Scaffold(body: Text('ALIGN_PAGE')),
          ),
          GoRoute(
            path: '/nav-routes/:id/3d',
            builder: (context, state) =>
                const Scaffold(body: Text('SEASCAPE_PAGE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider(route.id).overrideWith((ref) async => route),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-track-align')));
      await tester.pumpAndSettle();
      expect(find.text('ALIGN_PAGE'), findsOneWidget);
    });

    testWidgets('the 3D button pushes the seascape route', (tester) async {
      final overrides = await getBaseOverrides();
      final route = _route();
      final router = GoRouter(
        initialLocation: '/nav-routes/${route.id}',
        routes: [
          GoRoute(
            path: '/nav-routes/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/nav-routes/:id/3d',
            builder: (context, state) =>
                const Scaffold(body: Text('SEASCAPE_PAGE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            navTrackByIdProvider(route.id).overrideWith((ref) async => route),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-track-open-3d')));
      await tester.pumpAndSettle();
      expect(find.text('SEASCAPE_PAGE'), findsOneWidget);
    });
  });

  group('navTrackAnchorShouldFollowSiteChange (item 5)', () {
    test('the anchor follows the new site when it was never set', () {
      expect(
        navTrackAnchorShouldFollowSiteChange(null, const GeoPoint(47.1, 8.3)),
        isTrue,
      );
    });

    test('the anchor follows the new site when it still equals the old '
        'site\'s pin (the diver never moved the start point)', () {
      const oldSiteLocation = GeoPoint(47.1, 8.3);
      expect(
        navTrackAnchorShouldFollowSiteChange(oldSiteLocation, oldSiteLocation),
        isTrue,
      );
    });

    test('the anchor stays when the diver already moved it away from the old '
        'site\'s pin', () {
      const oldSiteLocation = GeoPoint(47.1, 8.3);
      const movedAnchor = GeoPoint(47.2, 8.4);
      expect(
        navTrackAnchorShouldFollowSiteChange(movedAnchor, oldSiteLocation),
        isFalse,
      );
    });
  });
}
