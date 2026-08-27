import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('SiteDetailPage Redirection Coverage', () {
    const site = DiveSite(id: 'site-1', name: 'Blue Hole');

    testWidgets('does not redirect on desktop if Navigator.canPop() is true', (
      tester,
    ) async {
      // Set desktop size
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/other',
        routes: [
          GoRoute(
            path: '/other',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/sites/site-1'),
                child: const Text('GO'),
              ),
            ),
          ),
          GoRoute(
            path: '/sites/site-1',
            builder: (context, state) => const SiteDetailPage(siteId: 'site-1'),
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
          ].cast<Override>(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      // Start at /other
      router.go('/other');
      await tester.pumpAndSettle();

      // Push /sites/site-1, so canPop() will be true
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();

      // We should be on SiteDetailPage, NOT redirected to /sites (which isn't even defined here, so it would error if it tried)
      expect(find.byType(SiteDetailPage), findsOneWidget);
      // Use find.descendant or a more specific finder to avoid finding multiple site names
      // (one in the header, one in the basic info section).
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Blue Hole'),
        ),
        findsOneWidget,
      );
    });
  });
}
