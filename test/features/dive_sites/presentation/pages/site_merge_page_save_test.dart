import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_routes.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_merge_page.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The merge page's save (issue #4527, phase 2, plan 7): a finished merge
/// returns its result, a merge the repository or the library refuses stays
/// on the page and says so, and the merge address needs two sites.
void main() {
  final l = AppLocalizationsEn();

  // The altitude fill calls Open-Meteo; it answers as offline.
  setUp(() => serveFakeHost('api.open-meteo.com'));

  late SharedPreferences prefs;
  late AppDatabase db;
  final divers = [
    for (final (id, name) in [('d1', 'Alice'), ('d2', 'Bob')])
      Diver(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await seedDivers(db, ['d1', 'd2']);
  });

  tearDown(tearDownTestDatabase);

  /// Pumps a list at `/` and pushes the merge page for [siteIds] over it as
  /// [active]; the returned future is what the page pops with.
  Future<Future<Object?>> pump(
    WidgetTester tester,
    List<String> siteIds, {
    required String active,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('SITES')),
          routes: [
            GoRoute(
              path: 'merge',
              builder: (_, _) => SiteMergePage(siteIds: siteIds),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => active),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final result = router.push<Object?>('/merge');
    await tester.pumpAndSettle();
    return result;
  }

  /// Saves, and confirms the merge.
  Future<void> saveAndMerge(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save).first);
    // The save spinner runs while the confirmation is open: no settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(l.diveSites_edit_appBar_merge).last);
    await tester.pumpAndSettle();
  }

  Future<bool> stored(String id) async =>
      await (db.select(
        db.diveSites,
      )..where((t) => t.id.equals(id))).getSingleOrNull() !=
      null;

  testWidgets('a merge returns its survivor and leaves one site', (
    tester,
  ) async {
    await seedSite(db, 'a', owner: 'd2', name: 'Salt Pier');
    await seedSite(db, 'b', owner: 'd2', name: 'Salt Pier North');
    final result = await pump(tester, const ['a', 'b'], active: 'd2');

    await saveAndMerge(tester);

    expect(find.text('SITES'), findsOneWidget);
    final merged = await result;
    expect(merged, isA<SiteMergeResult>());
    expect((merged! as SiteMergeResult).survivorId, 'a');
    expect((merged as SiteMergeResult).snapshot, isNotNull);
    expect(await stored('a'), isTrue);
    expect(await stored('b'), isFalse);
  });

  testWidgets('a merge the repository refuses stays on the page and says so', (
    tester,
  ) async {
    await seedSite(db, 'mine', owner: 'd2', name: 'My Pier');
    // Alice's: Bob may not merge it away.
    await seedSite(db, 'pier', owner: 'd1', shared: true, name: 'Salt Pier');
    var popped = false;
    final result = await pump(tester, const ['mine', 'pier'], active: 'd2');
    result.then((_) => popped = true).ignore();

    await saveAndMerge(tester);

    expect(find.text('SITES'), findsNothing);
    expect(find.text(l.sharedItems_notOwner_site), findsOneWidget);
    expect(popped, isFalse);
    expect(await stored('pier'), isTrue);
  });

  // Review Focus 3 (Question 3): the survivor is a shared site library's
  // site this profile only reads. The merge is refused, never sent as a
  // suggestion.
  testWidgets('a merge whose survivor this profile may not edit is refused', (
    tester,
  ) async {
    await seedSite(db, 'lib', owner: 'd2', name: 'Salt Pier');
    await seedSite(db, 'own', owner: 'd2', name: 'Salt Pier North');
    await db.customStatement(
      "UPDATE dive_sites SET shared_library_id = 'L' WHERE id = 'lib'",
    );
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms2',
        diverId: 'd2',
        libraryId: 'L',
        memberId: 'm2',
        displayName: 'Bob',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
    // Bob (m2) only reads.
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(owners: {'o'}, editors: {'m1'}),
      ),
    );
    var popped = false;
    final result = await pump(tester, const ['lib', 'own'], active: 'd2');
    result.then((_) => popped = true).ignore();

    await saveAndMerge(tester);

    expect(find.text('SITES'), findsNothing);
    expect(find.text(l.sharedItems_notOwner_site), findsOneWidget);
    expect(popped, isFalse);
    expect(await stored('lib'), isTrue);
    expect(await stored('own'), isTrue);
  });

  // The page never offers a reader's suggestion, whatever the survivor.
  testWidgets('the merge page offers no suggestion', (tester) async {
    await seedSite(db, 'lib', owner: 'd2', name: 'Salt Pier');
    await seedSite(db, 'own', owner: 'd2', name: 'Salt Pier North');
    await db.customStatement(
      "UPDATE dive_sites SET shared_library_id = 'L' WHERE id = 'lib'",
    );
    await pump(tester, const ['lib', 'own'], active: 'd2');

    expect(find.text(l.diveSites_edit_appBar_mergeSites), findsOneWidget);
    expect(find.text(l.sharedLibrary_suggest_note_label), findsNothing);
    expect(find.text(l.sharedLibrary_suggest_send), findsNothing);
  });

  // Review Focus 4: the merge address needs two sites to merge.
  testWidgets('the merge address with fewer than two sites goes back to '
      'the list', (tester) async {
    final router = GoRouter(
      initialLocation: '/sites',
      routes: [
        GoRoute(
          path: '/sites',
          builder: (_, _) => const Scaffold(body: Text('SITES')),
          routes: [
            GoRoute(
              path: 'merge',
              redirect: siteMergeRedirect,
              builder: (_, state) =>
                  Scaffold(body: Text('MERGE ${siteMergeIds(state.extra)}')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    for (final extra in <Object?>[
      null,
      const <String>[],
      const ['s1'],
      'not a list',
    ]) {
      router.go('/sites/merge', extra: extra);
      await tester.pumpAndSettle();
      expect(find.text('SITES'), findsOneWidget, reason: '$extra');
    }

    router.go('/sites/merge', extra: const ['s1', 's2']);
    await tester.pumpAndSettle();
    expect(find.text('MERGE [s1, s2]'), findsOneWidget);
  });
}
