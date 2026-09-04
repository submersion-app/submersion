import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_list_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Both location-lookup entries live in three different menus (issue #1187),
/// and each one has to hand the flow the right mode: filling blanks must not
/// silently overwrite, and refreshing must not silently skip complete sites.
/// This notifier records the mode and answers "no candidates", which ends the
/// flow at its snackbar without a database or a geocoder.
class _RecordingBackfill extends StateNotifier<BackfillState>
    implements SiteLocationBackfillNotifier {
  _RecordingBackfill() : super(const BackfillIdle());

  final List<SiteLocationLookupMode> counted = [];

  @override
  Future<List<DiveSite>> findCandidates(SiteLocationLookupMode mode) async {
    counted.add(mode);
    return const [];
  }

  @override
  void reset() => state = const BackfillIdle();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _MockSiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestSiteTableConfigNotifier
    extends EntityTableConfigNotifier<SiteField> {
  _TestSiteTableConfigNotifier()
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

void main() {
  late _RecordingBackfill backfill;

  Future<List<Override>> buildOverrides(ListViewMode viewMode) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      sortedSitesWithCountsProvider.overrideWith(
        (ref) => const AsyncValue.data(<SiteWithDiveCount>[]),
      ),
      siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
      siteListViewModeProvider.overrideWith((ref) => viewMode),
      siteTableConfigProvider.overrideWith(
        (ref) => _TestSiteTableConfigNotifier(),
      ),
      siteLocationBackfillProvider.overrideWith((_) => backfill),
    ];
  }

  Widget host(Widget child, List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      // Pinned so the English finders below do not follow the host locale.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/sites',
        routes: [GoRoute(path: '/sites', builder: (_, _) => child)],
      ),
    ),
  );

  void useSurface(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Opens the overflow menu and picks [entry].
  Future<void> choose(WidgetTester tester, String entry) async {
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  setUp(() => backfill = _RecordingBackfill());

  group('site list menus', () {
    testWidgets('the phone app bar runs both modes', (tester) async {
      useSurface(tester, const Size(500, 900));
      final overrides = await buildOverrides(ListViewMode.detailed);
      await tester.pumpWidget(
        host(const SiteListContent(showAppBar: true), overrides),
      );
      await tester.pumpAndSettle();

      await choose(tester, 'Refresh place names');
      expect(backfill.counted, [SiteLocationLookupMode.refreshAll]);
      expect(find.text('No site has coordinates to look up.'), findsOneWidget);

      await choose(tester, 'Fill in missing location details');
      expect(backfill.counted.last, SiteLocationLookupMode.fillMissing);
    });

    testWidgets('the embedded compact app bar runs both modes', (tester) async {
      useSurface(tester, const Size(1200, 900));
      final overrides = await buildOverrides(ListViewMode.detailed);
      // showAppBar false is the embedded case, which supplies the compact bar
      // instead. It renders no Scaffold, so the flow's snackbar needs one.
      await tester.pumpWidget(
        host(
          const Scaffold(body: SiteListContent(showAppBar: false)),
          overrides,
        ),
      );
      await tester.pumpAndSettle();

      await choose(tester, 'Refresh place names');
      expect(backfill.counted, [SiteLocationLookupMode.refreshAll]);

      await choose(tester, 'Fill in missing location details');
      expect(backfill.counted.last, SiteLocationLookupMode.fillMissing);
    });

    testWidgets('the table page app bar runs both modes', (tester) async {
      useSurface(tester, const Size(1200, 900));
      final overrides = await buildOverrides(ListViewMode.table);
      await tester.pumpWidget(host(const SiteListPage(), overrides));
      await tester.pumpAndSettle();

      await choose(tester, 'Refresh place names');
      expect(backfill.counted, [SiteLocationLookupMode.refreshAll]);

      await choose(tester, 'Fill in missing location details');
      expect(backfill.counted.last, SiteLocationLookupMode.fillMissing);
    });
  });
}
