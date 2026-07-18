import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveListPage Embedded Site Coverage', () {
    late DiveRepository repository;
    late SiteRepository siteRepository;
    const diveId = 'dive-1';
    const siteId = 'site-1';
    const site = DiveSite(id: siteId, name: 'Nested Site');
    final dive = Dive(
      id: diveId,
      diveNumber: 1,
      dateTime: DateTime(2023, 1, 1),
      site: site,
    );

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
      siteRepository = SiteRepository();
      await siteRepository.createSite(site);
      await repository.createDive(dive);
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('renders embedded site when site query parameter is present', (
      tester,
    ) async {
      // Desktop size
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/dives?selected=$diveId&site=$siteId',
        routes: [
          GoRoute(
            path: '/dives',
            builder: (context, state) => const DiveListPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith(
              (ref) => DiveListNotifier(repository, ref),
            ),
            paginatedDiveListProvider.overrideWith(
              (ref) => PaginatedDiveListNotifier(repository, ref),
            ),
            customTankPresetsProvider.overrideWith((ref) async => []),
            siteProvider(siteId).overrideWith((ref) async => site),
            siteDiveCountProvider(siteId).overrideWith((ref) async => 0),
            diveProvider(diveId).overrideWith((ref) async => dive),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the site name because it's embedded
      // Use find.descendant with a more specific title style or another unique property
      // to avoid finding multiple site names (one in header, one in Card, one in list).
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Nested Site'),
        ),
        findsAtLeastNWidgets(1),
      );
      expect(find.byType(SiteDetailPage), findsOneWidget);
    });
  });
}
