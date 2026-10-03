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
  String? setSiteRouteId;
  String? setSiteId;
  GeoPoint? setSiteAnchor;
  bool? setSiteClearAnchor;

  @override
  Future<void> rename(String routeId, String? name) async {
    renamedId = routeId;
    newName = name;
  }

  @override
  Future<void> setSite(
    String routeId,
    String? siteId, {
    GeoPoint? anchor,
    bool clearAnchor = false,
  }) async {
    setSiteRouteId = routeId;
    setSiteId = siteId;
    setSiteAnchor = anchor;
    setSiteClearAnchor = clearAnchor;
  }

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    linkedRouteId = routeId;
    linkedDiveId = diveId;
    this.linkMode = linkMode;
    return true;
  }

  @override
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) async {
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
  List<DiveSite>? allSites,
  Locale? locale,
  _RecordingNavTrackRepository? repository,
}) async {
  final overrides = await getBaseOverrides();
  final effectiveRepository = repository ?? _RecordingNavTrackRepository();
  final effectiveOverrides = [
    ...overrides,
    navTrackByIdProvider(route.id).overrideWith((ref) async => route),
    navTrackRepositoryProvider.overrideWithValue(effectiveRepository),
    if (linkedDive != null)
      diveProvider(linkedDive.id).overrideWith((ref) async => linkedDive),
    if (equipment != null)
      equipmentItemProvider(
        equipment.id,
      ).overrideWith((ref) async => equipment),
    if (site != null) siteProvider(site.id).overrideWith((ref) async => site),
    if (allDives != null) divesProvider.overrideWith((ref) async => allDives),
    if (allSites != null) sitesProvider.overrideWith((ref) async => allSites),
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
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavTrackDetailPage(trackId: route.id),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  return effectiveRepository;
}

void main() {
  testWidgets('shows "No dive linked" for an unlinked route', (tester) async {
    await _pump(tester, route: _route());

    expect(find.byKey(const ValueKey('nav-track-no-dive')), findsOneWidget);
    expect(find.text('No dive linked'), findsOneWidget);
    expect(find.text('Choose dive'), findsOneWidget);
  });

  group('on a narrow phone in German (#2692)', () {
    // A ListTile measures its trailing widget against the full tile width
    // first, so a translated action button there ("Tauchgang wählen",
    // "Tauchplatz wählen") starved the card's label down to one fragment per
    // line. The action belongs below the label instead.
    Future<void> pumpNarrow(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester, route: _route(), locale: const Locale('de'));
    }

    void expectReadableAboveAction(
      WidgetTester tester, {
      required String label,
      required Finder action,
    }) {
      final labelRect = tester.getRect(find.text(label));
      final actionRect = tester.getRect(action);
      expect(
        labelRect.width,
        greaterThan(150),
        reason:
            '"$label" collapsed to ${labelRect.width}px wide on a 360px '
            'screen; the action button is starving the ListTile text column.',
      );
      expect(actionRect.top, greaterThanOrEqualTo(labelRect.bottom));
    }

    testWidgets('the "no dive linked" card keeps its label readable', (
      tester,
    ) async {
      await pumpNarrow(tester);

      expectReadableAboveAction(
        tester,
        label: 'Kein Tauchgang verknüpft',
        action: find.widgetWithText(TextButton, 'Tauchgang wählen'),
      );
    });

    testWidgets('the site card keeps its label readable', (tester) async {
      await pumpNarrow(tester);

      expectReadableAboveAction(
        tester,
        label: 'Kein Tauchplatz',
        action: find.byKey(const ValueKey('nav-track-change-site')),
      );
    });
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

  testWidgets('a linked dive without a number is labelled by its id, not as a '
      'numbered dive (matching the routes list chip)', (tester) async {
    final dive = Dive(id: 'dive-1', dateTime: DateTime(2026, 8, 22, 10, 8));
    await _pump(
      tester,
      route: _route(diveId: 'dive-1'),
      linkedDive: dive,
    );

    expect(find.text('Dive dive-1'), findsOneWidget);
    expect(find.text('Dive #dive-1'), findsNothing);
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

  testWidgets(
    '"Choose dive" pre-selects the sole dive NavTrackMatchService suggests '
    '(#2394)',
    (tester) async {
      // Entry time equals the route's own startTime (1755856800000ms), so
      // this is the sole dive NavTrackMatcher.candidatesFor overlaps --
      // no fake match service needed, the pre-selection is computed
      // directly from the dives already fetched for the sheet.
      final candidate = Dive(
        id: 'dive-9',
        diveNumber: 9,
        dateTime: DateTime.fromMillisecondsSinceEpoch(1755856800000),
        entryTime: DateTime.fromMillisecondsSinceEpoch(1755856800000),
      );
      await _pump(tester, route: _route(), allDives: [candidate]);

      await tester.tap(find.text('Choose dive'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('nav-track-dive-choice-dive-9')),
            )
            .selected,
        isTrue,
      );
    },
  );

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

    testWidgets('picking an existing site in the picker assigns it to the '
        'route', (tester) async {
      const oldSite = DiveSite(
        id: 'site-1',
        name: 'Test Site',
        location: GeoPoint(47.1, 8.3),
      );
      const newSite = DiveSite(
        id: 'site-2',
        name: 'Other Site',
        location: GeoPoint(47.2, 8.4),
      );
      final repository = await _pump(
        tester,
        route: _route(siteId: 'site-1'),
        site: oldSite,
        allSites: [oldSite, newSite],
      );

      await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(newSite.name));
      await tester.pumpAndSettle();

      expect(repository.setSiteRouteId, 'r1');
      expect(repository.setSiteId, 'site-2');
      expect(repository.setSiteAnchor, const GeoPoint(47.2, 8.4));
    });

    testWidgets(
      'creating a new site in the picker pushes /sites/new and assigns the '
      'saved site to the route',
      (tester) async {
        final route = _route();
        const newSite = DiveSite(
          id: 'site-new',
          name: 'Brand New Site',
          location: GeoPoint(47.5, 8.6),
        );
        final router = GoRouter(
          initialLocation: '/tracks/underwater/${route.id}',
          routes: [
            GoRoute(
              path: '/tracks/underwater/:id',
              builder: (context, state) =>
                  NavTrackDetailPage(trackId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/sites/new',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(newSite.id),
                  child: const Text('save new site'),
                ),
              ),
            ),
          ],
        );
        final repository = await _pump(
          tester,
          route: route,
          router: router,
          site: newSite,
          allSites: const [],
        );

        await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Dive Site'));
        await tester.pumpAndSettle();

        expect(find.text('save new site'), findsOneWidget);
        await tester.tap(find.text('save new site'));
        await tester.pumpAndSettle();

        expect(repository.setSiteRouteId, 'r1');
        expect(repository.setSiteId, 'site-new');
        expect(repository.setSiteAnchor, const GeoPoint(47.5, 8.6));
      },
    );

    testWidgets(
      'creating a new site seeds the form with the route anchor and keeps a '
      'hand-placed anchor',
      (tester) async {
        final route = _route(anchorLatitude: 47.3, anchorLongitude: 8.5);
        const newSite = DiveSite(
          id: 'site-new',
          name: 'Brand New Site',
          location: GeoPoint(47.3, 8.5),
        );
        Object? seededLocation;
        final router = GoRouter(
          initialLocation: '/tracks/underwater/${route.id}',
          routes: [
            GoRoute(
              path: '/tracks/underwater/:id',
              builder: (context, state) =>
                  NavTrackDetailPage(trackId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/sites/new',
              builder: (context, state) {
                seededLocation = state.extra;
                return Scaffold(
                  body: TextButton(
                    onPressed: () => context.pop(newSite.id),
                    child: const Text('save new site'),
                  ),
                );
              },
            ),
          ],
        );
        final repository = await _pump(
          tester,
          route: route,
          router: router,
          site: newSite,
          allSites: const [],
        );

        await tester.tap(find.byKey(const ValueKey('nav-track-change-site')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Dive Site'));
        await tester.pumpAndSettle();

        expect(seededLocation, const GeoPoint(47.3, 8.5));
        await tester.tap(find.text('save new site'));
        await tester.pumpAndSettle();

        // The anchor was placed by hand (no old site), so the site change
        // must not rewrite it.
        expect(repository.setSiteId, 'site-new');
        expect(repository.setSiteAnchor, isNull);
        expect(repository.setSiteClearAnchor, isFalse);
      },
    );
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
                onPressed: () => context.push('/tracks/underwater/${route.id}'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: '/tracks/underwater/:id',
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
        initialLocation: '/tracks/underwater/${route.id}',
        routes: [
          GoRoute(
            path: '/tracks/underwater/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/tracks/underwater/:id/align',
            builder: (context, state) =>
                const Scaffold(body: Text('ALIGN_PAGE')),
          ),
          GoRoute(
            path: '/tracks/underwater/:id/3d',
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
        initialLocation: '/tracks/underwater/${route.id}',
        routes: [
          GoRoute(
            path: '/tracks/underwater/:id',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/tracks/underwater/:id/3d',
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

  group('navTrackAnchorChangeForSite', () {
    const oldPin = GeoPoint(47.1, 8.3);
    const newPin = GeoPoint(47.2, 8.4);

    test('moves an anchor that followed the old pin to the new pin', () {
      expect(navTrackAnchorChangeForSite(oldPin, oldPin, newPin), (
        write: true,
        anchor: newPin,
      ));
    });

    test('clears an anchor that followed the old pin when the new site has '
        'no pin, rather than leaving the route at the old site', () {
      expect(navTrackAnchorChangeForSite(oldPin, oldPin, null), (
        write: true,
        anchor: null,
      ));
    });

    test('leaves a hand-placed anchor alone', () {
      expect(
        navTrackAnchorChangeForSite(const GeoPoint(50, 10), oldPin, newPin),
        (write: false, anchor: null),
      );
    });
  });
}
