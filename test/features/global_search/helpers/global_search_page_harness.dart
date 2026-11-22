import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/ui/app_actions.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/pages/global_search_page.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_record_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// The Search page harness its test files share: the records each section
// reads, the list routes See all lands on, and the app around the page.

class _StubSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The query every [globalSearchSection] carries.
final globalSearchTestQuery = TextNode(['reef']);

/// A section of [kind] with [count] hits, `id0` up, of [total] in all.
GlobalSearchSection globalSearchSection(
  GlobalSearchKind kind,
  int count, {
  int? total,
}) => GlobalSearchSection(
  kind: kind,
  total: total ?? count,
  query: globalSearchTestQuery,
  hasList: !const {
    GlobalSearchKind.equipmentSets,
    GlobalSearchKind.documents,
    GlobalSearchKind.divePlans,
    GlobalSearchKind.gpsTracks,
    GlobalSearchKind.underwaterRoutes,
  }.contains(kind),
  ids: [for (var i = 0; i < count; i++) 'id$i'],
);

final _now = DateTime(2026, 10, 30);

/// What the Buddies list holds: `Hit 0`, `Hit 1`, and so on.
final _buddies = [
  for (var i = 0; i < 10; i++)
    BuddyWithDiveCount(
      buddy: Buddy(
        id: 'id$i',
        name: 'Hit $i',
        createdAt: _now,
        updatedAt: _now,
      ),
      diveCount: 0,
    ),
];

/// What the equipment sets hold: `Set 0`, `Set 1`, and so on.
final _sets = [
  for (var i = 0; i < 10; i++)
    EquipmentSet(id: 'id$i', name: 'Set $i', createdAt: _now, updatedAt: _now),
];

/// The list routes See all can land on, each a page naming its address.
List<RouteBase> _routes() => [
  GoRoute(path: '/search', builder: (c, s) => const GlobalSearchPage()),
  for (final path in const [
    '/dives',
    '/sites',
    '/trips',
    '/equipment',
    '/buddies',
    '/dive-centers',
    '/certifications',
    '/courses',
    '/species/manage',
    '/buddies/:id',
  ])
    GoRoute(
      path: path,
      builder: (c, s) => Scaffold(body: Text('page ${s.uri.path}')),
    ),
];

/// The Search page at [initialLocation], answering each search with
/// [answer], over the app's own actions. With [appShortcuts] the app's
/// global shortcuts are bound over every page, as the shell binds them, and
/// their process-wide state is put back after the test.
Widget globalSearchPageApp(
  Future<List<GlobalSearchSection>> Function(String text) answer, {
  required SharedPreferences prefs,
  List<dynamic> overrides = const [],
  String initialLocation = '/search',
  bool appShortcuts = false,
}) {
  if (appShortcuts) addTearDown(AppShortcuts.debugReset);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: appShortcuts
        // The app's own shortcuts over every page, as the shell binds them.
        ? [
            ShellRoute(
              builder: (context, state, child) => CallbackShortcuts(
                bindings: AppShortcuts.globalBindings(context),
                child: Focus(autofocus: true, child: child),
              ),
              routes: _routes(),
            ),
          ]
        : _routes(),
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => _StubSettings()),
      certificationCatalogSyncProvider.overrideWithValue(
        CertificationCatalog.builtInOnly,
      ),
      globalSearchProvider.overrideWith((ref, text) => answer(text)),
      queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      queryUnitPrefsProvider.overrideWithValue(kMetricPrefs),
      globalSearchBuddiesProvider.overrideWith(
        (ref, key) async => [
          for (final entry in _buddies)
            if (globalSearchIdsOf(key).contains(entry.buddy.id)) entry,
        ],
      ),
      globalSearchEquipmentSetsProvider.overrideWith(
        (ref, key) async => [
          for (final set in _sets)
            if (globalSearchIdsOf(key).contains(set.id)) set,
        ],
      ),
      // The other sections stay empty: See all reads the section, not its
      // rows.
      globalSearchDivesProvider.overrideWith((ref, key) async => const []),
      globalSearchSitesProvider.overrideWith((ref, key) async => const []),
      globalSearchTripsProvider.overrideWith((ref, key) async => const []),
      globalSearchEquipmentProvider.overrideWith((ref, key) async => const []),
      globalSearchDiveCentersProvider.overrideWith(
        (ref, key) async => const [],
      ),
      globalSearchCertificationsProvider.overrideWith(
        (ref, key) async => const [],
      ),
      globalSearchCoursesProvider.overrideWith((ref, key) async => const []),
      globalSearchSpeciesProvider.overrideWith((ref, key) async => const []),
      ...overrides.cast(),
    ],
    child: MaterialApp.router(
      // The app's own, as lib/app.dart sets them: a tap off the field puts
      // the keyboard away.
      actions: appActions(),
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Types [text] into the field and waits out the debounce and the load.
Future<void> searchGlobally(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const ValueKey('global-search-field')),
    text,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}
