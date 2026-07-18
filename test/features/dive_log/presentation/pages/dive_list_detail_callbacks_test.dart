import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveListPage detailBuilder embedded-site callbacks', () {
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

    // Pumps DiveListPage on a desktop viewport with the detail pane showing an
    // embedded site (?selected=dive-1&site=site-1), returning the router. The
    // detail pane's DiveDetailPage carries the callbacks under test.
    Future<GoRouter> pumpEmbeddedSite(
      WidgetTester tester, {
      required bool tableMode,
      required void Function(String) onNavigate,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/dives?selected=$diveId&site=$siteId',
        redirect: (context, state) {
          onNavigate(state.uri.toString());
          return null;
        },
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
            diveDataSourcesProvider(diveId).overrideWith((ref) async => []),
            if (tableMode) ...[
              diveListViewModeProvider.overrideWith(
                (ref) => ListViewMode.table,
              ),
              tableDetailsPaneProvider('dives').overrideWith((ref) => true),
            ],
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();

      // The embedded site confirms the detailBuilder ran with the site param.
      expect(find.byType(SiteDetailPage), findsOneWidget);
      return router;
    }

    DiveDetailPage detailPage(WidgetTester tester) =>
        tester.widget<DiveDetailPage>(find.byType(DiveDetailPage));

    for (final tableMode in [false, true]) {
      final label = tableMode ? 'table mode' : 'detailed mode';

      testWidgets('$label: onCloseEmbeddedSite drops the site query param', (
        tester,
      ) async {
        String? location;
        await pumpEmbeddedSite(
          tester,
          tableMode: tableMode,
          onNavigate: (loc) => location = loc,
        );

        final page = detailPage(tester);
        expect(page.embeddedSiteId, siteId);

        page.onCloseEmbeddedSite!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        tester.takeException();

        // Site cleared, dive selection preserved.
        expect(location, isNotNull);
        expect(location, isNot(contains('site=')));
        expect(location, contains('selected=$diveId'));
      });

      testWidgets('$label: onDeleted clears the selection back to the list', (
        tester,
      ) async {
        String? location;
        await pumpEmbeddedSite(
          tester,
          tableMode: tableMode,
          onNavigate: (loc) => location = loc,
        );

        detailPage(tester).onDeleted!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        tester.takeException();

        // Back to the bare list path, no selection or site.
        expect(location, '/dives');
      });
    }
  });
}
