import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_list_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_notice.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// The ways from the Sites page into the review of built-in details: the
/// overflow menu's entry, in each of the three places that menu is built,
/// and the notice above the list.
class _SiteTableConfig extends EntityTableConfigNotifier<SiteField> {
  _SiteTableConfig()
    : super(
        defaultConfig: EntityTableViewConfig<SiteField>(
          columns: [
            EntityTableColumnConfig(field: SiteField.siteName, isPinned: true),
            EntityTableColumnConfig(field: SiteField.country),
          ],
        ),
        fieldFromName: SiteFieldAdapter.instance.fieldFromName,
      );
}

class _SiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _SiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _site = DiveSite(id: 's1', name: 'Salt Pier', catalogueId: 'r1');
const _rows = [SiteWithDiveCount(site: _site, diveCount: 3)];

const _pair = CataloguePair(
  site: _site,
  record: CatalogueSite(id: 'r1', name: 'Salt Pier', source: 'osm'),
  kind: CataloguePairKind.linked,
  fields: {CatalogueGapField.depth},
);

const _menuEntry = 'Check sites against built-in catalogue';
const _notice = 'Built-in details are available for your sites (1)';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    ListViewMode viewMode = ListViewMode.detailed,
    List<CataloguePair> pairs = const [],
    SiteFilterState filter = const SiteFilterState(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/sites',
      routes: [
        GoRoute(
          path: '/sites',
          builder: (_, _) => const SiteListPage(),
          routes: [
            GoRoute(
              path: 'catalogue-review',
              builder: (_, _) => const Scaffold(body: Text('review page')),
            ),
            GoRoute(
              path: ':id',
              builder: (_, _) => const Scaffold(body: Text('detail')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) =>
                MockSettingsNotifier(AppSettings(siteListViewMode: viewMode)),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          sortedSitesWithCountsProvider.overrideWith(
            (ref) => const AsyncValue.data(_rows),
          ),
          siteListNotifierProvider.overrideWith((ref) => _SiteListNotifier()),
          siteTableConfigProvider.overrideWith((ref) => _SiteTableConfig()),
          siteFilterProvider.overrideWith((ref) => filter),
          catalogueGapPairsProvider.overrideWith((ref) async => pairs),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenuAndChoose(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text(_menuEntry), findsOneWidget);
    await tester.tap(find.text(_menuEntry));
    await tester.pumpAndSettle();
  }

  group('the overflow menu opens the review', () {
    testWidgets('on a phone', (tester) async {
      await pump(tester, size: const Size(390, 844));

      await openMenuAndChoose(tester);

      expect(find.text('review page'), findsOneWidget);
    });

    testWidgets('beside the detail pane on a wide screen', (tester) async {
      await pump(tester, size: const Size(1400, 900));

      await openMenuAndChoose(tester);

      expect(find.text('review page'), findsOneWidget);
    });

    testWidgets('in table mode', (tester) async {
      await pump(
        tester,
        size: const Size(1400, 900),
        viewMode: ListViewMode.table,
      );

      await openMenuAndChoose(tester);

      expect(find.text('review page'), findsOneWidget);
    });
  });

  group('the notice above the list', () {
    testWidgets('shows on a phone when details are waiting', (tester) async {
      await pump(tester, size: const Size(390, 844), pairs: [_pair]);

      expect(find.text(_notice), findsOneWidget);
      // Above the list, not over it.
      expect(
        tester.getBottomLeft(find.byType(CatalogueGapNotice)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Salt Pier')).dy),
      );
    });

    testWidgets('shows beside the detail pane on a wide screen', (
      tester,
    ) async {
      await pump(tester, size: const Size(1400, 900), pairs: [_pair]);

      expect(find.text(_notice), findsOneWidget);
    });

    testWidgets('shows in table mode', (tester) async {
      await pump(
        tester,
        size: const Size(1400, 900),
        viewMode: ListViewMode.table,
        pairs: [_pair],
      );

      expect(find.text(_notice), findsOneWidget);
    });

    testWidgets('is absent with nothing waiting', (tester) async {
      await pump(tester, size: const Size(390, 844));

      expect(
        find.textContaining('Built-in details are available'),
        findsNothing,
      );
    });

    testWidgets('stays out of the way while the list is filtered', (
      tester,
    ) async {
      await pump(
        tester,
        size: const Size(390, 844),
        pairs: [_pair],
        filter: const SiteFilterState(country: 'Egypt'),
      );

      expect(
        find.textContaining('Built-in details are available'),
        findsNothing,
      );
    });

    testWidgets('stays out of the way in a filtered table', (tester) async {
      await pump(
        tester,
        size: const Size(1400, 900),
        viewMode: ListViewMode.table,
        pairs: [_pair],
        filter: const SiteFilterState(country: 'Egypt'),
      );

      expect(
        find.textContaining('Built-in details are available'),
        findsNothing,
      );
    });
  });
}
