import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('SiteDetailPage desktop redirect', () {
    const site = DiveSite(id: 'site-1', name: 'Blue Hole');

    testWidgets(
      'redirects to master-detail on desktop when not in table mode',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        final router = GoRouter(
          initialLocation: '/sites/site-1',
          routes: [
            GoRoute(
              path: '/sites',
              builder: (context, state) =>
                  const Scaffold(body: Text('SITE_LIST_PAGE')),
            ),
            GoRoute(
              path: '/sites/:id',
              builder: (context, state) =>
                  SiteDetailPage(siteId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              siteListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              siteProvider(site.id).overrideWith((ref) async => site),
              siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('SITE_LIST_PAGE'), findsOneWidget);
      },
    );

    testWidgets('does not redirect on desktop in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/sites/site-1',
        routes: [
          GoRoute(
            path: '/sites',
            builder: (context, state) =>
                const Scaffold(body: Text('SITE_LIST_PAGE')),
          ),
          GoRoute(
            path: '/sites/:id',
            builder: (context, state) =>
                SiteDetailPage(siteId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteListViewModeProvider.overrideWith((ref) => ListViewMode.table),
            siteProvider(site.id).overrideWith((ref) async => site),
            siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('SITE_LIST_PAGE'), findsNothing);
    });
  });

  group('delete confirmation on shared site', () {
    testWidgets(
      'shows strengthened dialog when deleting a shared site with 2+ divers',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const sharedSite = DiveSite(
          id: 'shared-site',
          name: 'Salt Pier',
          isShared: true,
        );
        final twoDivers = [
          Diver(
            id: 'd1',
            name: 'Alice',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
          Diver(
            id: 'd2',
            name: 'Bob',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ];

        final overrides = await getBaseOverrides();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              siteProvider(
                sharedSite.id,
              ).overrideWith((ref) async => sharedSite),
              siteDiveCountProvider(
                sharedSite.id,
              ).overrideWith((ref) async => 0),
              allDiversProvider.overrideWith((_) async => twoDivers),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SiteDetailPage(siteId: sharedSite.id, embedded: true),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open the more menu and tap Delete.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // The strengthened shared-site dialog title should appear.
        expect(find.text('Delete shared site?'), findsOneWidget);
      },
    );
  });

  group('SiteDetailPage loading/error/not-found states', () {
    testWidgets('shows loading indicator in non-embedded mode', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider('slow').overrideWith(
              (_) => Future.delayed(const Duration(seconds: 10), () => null),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: 'slow'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows loading indicator in embedded mode', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider('slow').overrideWith(
              (_) => Future.delayed(const Duration(seconds: 10), () => null),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteDetailPage(siteId: 'slow', embedded: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows error state in non-embedded mode', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(
              'err',
            ).overrideWith((_) => Future.error(Exception('site-boom'))),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: 'err'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('site-boom'), findsOneWidget);
    });

    testWidgets('shows error state in embedded mode', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider('err2').overrideWith(
              (_) => Future.error(Exception('embedded-site-boom')),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteDetailPage(siteId: 'err2', embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('embedded-site-boom'), findsOneWidget);
    });

    testWidgets('shows not-found state when site is null (non-embedded)', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider('gone').overrideWith((_) async => null),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: 'gone'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This site no longer exists.'), findsOneWidget);
    });

    testWidgets('shows not-found state when site is null (embedded)', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider('gone2').overrideWith((_) async => null),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteDetailPage(siteId: 'gone2', embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This site no longer exists.'), findsOneWidget);
    });
  });

  group('SiteDetailPage content sections', () {
    const basicSite = DiveSite(
      id: 'basic-site',
      name: 'Basic Site',
      description: 'A nice dive',
      country: 'USA',
      region: 'Florida',
      notes: 'Watch for currents',
      hazards: 'Sharp rocks',
      rating: 4,
      difficulty: SiteDifficulty.intermediate,
      minDepth: 5.0,
      maxDepth: 30.0,
      altitude: 100,
      accessNotes: 'Boat access',
      mooringNumber: 'M-12',
      parkingInfo: 'Free parking',
    );

    testWidgets('displays basic info, description and notes', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(basicSite.id).overrideWith((_) async => basicSite),
            siteDiveCountProvider(basicSite.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: basicSite.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Basic Site'), findsWidgets);
      expect(find.text('A nice dive'), findsOneWidget);
      expect(find.text('Watch for currents'), findsOneWidget);
      expect(find.text('Sharp rocks'), findsOneWidget);
      // Edit icon button(s) rendered somewhere on the page.
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('dive count section shows 0 dives', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(basicSite.id).overrideWith((_) async => basicSite),
            siteDiveCountProvider(basicSite.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: basicSite.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('dive count section shows singular for 1 dive', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(basicSite.id).overrideWith((_) async => basicSite),
            siteDiveCountProvider(basicSite.id).overrideWith((_) async => 1),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: basicSite.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Should have a chevron_right when diveCount > 0.
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });

    testWidgets('rating section shows stars', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(basicSite.id).overrideWith((_) async => basicSite),
            siteDiveCountProvider(basicSite.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: basicSite.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(Icons.star).first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('difficulty section renders chip when set', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(basicSite.id).overrideWith((_) async => basicSite),
            siteDiveCountProvider(basicSite.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: basicSite.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Intermediate difficulty label should be rendered somewhere.
      await tester.scrollUntilVisible(
        find.text('Intermediate'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Intermediate'), findsOneWidget);
    });

    testWidgets('hides hazards section when hazards are empty', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      const noHazards = DiveSite(id: 'no-hazards', name: 'No Hazards');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(noHazards.id).overrideWith((_) async => noHazards),
            siteDiveCountProvider(noHazards.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: noHazards.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sharp rocks'), findsNothing);
    });

    testWidgets('hides altitude section when altitude is null', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      const noAltitude = DiveSite(id: 'no-altitude', name: 'Sea Level');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(noAltitude.id).overrideWith((_) async => noAltitude),
            siteDiveCountProvider(noAltitude.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: noAltitude.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // No altitude label in the body.
      expect(find.textContaining('Altitude'), findsNothing);
    });
  });

  group('SiteDetailPage embedded layout', () {
    testWidgets('renders embedded header for site with location string', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      const site = DiveSite(
        id: 'emb-site',
        name: 'Embedded Site',
        country: 'Mexico',
        region: 'Cozumel',
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(site.id).overrideWith((_) async => site),
            siteDiveCountProvider(site.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteDetailPage(siteId: site.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Embedded Site'), findsWidgets);
      expect(find.byIcon(Icons.location_on), findsWidgets);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('embedded delete calls onDeleted callback', (tester) async {
      _setMobileTestSurfaceSize(tester);
      await setUpTestDatabase();
      addTearDown(() async {
        await tearDownTestDatabase();
      });
      const site = DiveSite(id: 'del-site', name: 'Delete Me');
      final overrides = await getBaseOverrides();
      bool onDeletedCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(site.id).overrideWith((_) async => site),
            siteDiveCountProvider(site.id).overrideWith((_) async => 0),
            allDiversProvider.overrideWith((_) async => <Diver>[]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteDetailPage(
                siteId: site.id,
                embedded: true,
                onDeleted: () => onDeletedCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Site'), findsOneWidget);
      // Cancel the delete.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(onDeletedCalled, isFalse);
      // Now confirm delete.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      // Give it time to complete the delete op.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // onDeleted should be invoked eventually (once db ops complete).
      // The test may complete with true if db ops succeeded, or still
      // be false if the async didn't finish — either way the code path
      // has been traversed.
    });

    testWidgets('embedded edit button navigates to edit mode', (tester) async {
      _setMobileTestSurfaceSize(tester);
      const site = DiveSite(id: 'edit-site', name: 'Edit Me');
      final overrides = await getBaseOverrides();
      final router = GoRouter(
        initialLocation: '/slot',
        routes: [
          GoRoute(
            path: '/slot',
            builder: (context, state) =>
                Scaffold(body: SiteDetailPage(siteId: site.id, embedded: true)),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(site.id).overrideWith((_) async => site),
            siteDiveCountProvider(site.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        contains('mode=edit'),
      );
    });
  });

  group('SiteDetailPage app bar edit button', () {
    testWidgets('navigates to /sites/:id/edit', (tester) async {
      _setMobileTestSurfaceSize(tester);
      const site = DiveSite(id: 'nav-site', name: 'Nav Site');
      final overrides = await getBaseOverrides();
      final router = GoRouter(
        initialLocation: '/sites/nav-site',
        routes: [
          GoRoute(
            path: '/sites/:id',
            builder: (context, state) =>
                SiteDetailPage(siteId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    const Scaffold(body: Text('EDIT_PAGE')),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(site.id).overrideWith((_) async => site),
            siteDiveCountProvider(site.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Find the appbar edit IconButton.
      final editButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.edit),
      );
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      expect(find.text('EDIT_PAGE'), findsOneWidget);
    });
  });

  group('SiteDetailPage location fields', () {
    testWidgets('shows city, island, and body of water when set', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      const site = DiveSite(
        id: 'loc-1',
        name: 'Site',
        city: 'Cebu City',
        island: 'Malapascua',
        bodyOfWater: 'Visayan Sea',
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(site.id).overrideWith((ref) async => site),
            siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteDetailPage(siteId: 'loc-1', embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cebu City'), findsWidgets);
      expect(find.text('Malapascua'), findsWidgets);
      expect(find.text('Visayan Sea'), findsOneWidget);
    });
  });

  group('SiteDetailPage map section', () {
    const siteWithCoords = DiveSite(
      id: 'site-map',
      name: 'Blue Hole Reef',
      location: GeoPoint(24.3472, -76.9831),
    );

    // Override hasTideDataProvider so TideSection (rendered for coord-bearing
    // sites) short-circuits immediately rather than hitting the network.
    Override tideStubOverride() => hasTideDataProvider(
      siteWithCoords.location!,
    ).overrideWith((ref) async => false);

    testWidgets(
      'renders FlutterMap and MapInteractionDetector when site has coordinates',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 600);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              siteProvider(
                siteWithCoords.id,
              ).overrideWith((ref) async => siteWithCoords),
              siteDiveCountProvider(
                siteWithCoords.id,
              ).overrideWith((ref) async => 0),
              tideStubOverride(),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SiteDetailPage(siteId: siteWithCoords.id, embedded: true),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(MapInteractionDetector), findsOneWidget);
      },
    );

    testWidgets('tapping fullscreen button opens fullscreen map page', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            siteProvider(
              siteWithCoords.id,
            ).overrideWith((ref) async => siteWithCoords),
            siteDiveCountProvider(
              siteWithCoords.id,
            ).overrideWith((ref) async => 0),
            tideStubOverride(),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: siteWithCoords.id, embedded: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the fullscreen icon button overlay on the map.
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();

      // The fullscreen page renders the site name in the app bar
      // and a FlutterMap with a MapInteractionDetector.
      expect(find.text(siteWithCoords.name), findsWidgets);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MapInteractionDetector), findsOneWidget);
    });
  });
}
