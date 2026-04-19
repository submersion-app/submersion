import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

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
}
