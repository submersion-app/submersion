import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The site list's bulk delete and merge with another profile's shared
/// sites in the selection (issue #2594).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await seedDivers(db, ['d1', 'd2']);
  });

  tearDown(tearDownTestDatabase);

  /// Pumps the list as profile d2 and returns what a merge was asked for.
  Future<List<List<String>>> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final merges = <List<String>>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: SiteListContent(showAppBar: false)),
        ),
        GoRoute(
          path: '/sites/merge',
          builder: (context, state) {
            merges.add(List<String>.from(state.extra! as List));
            return const Scaffold(body: Text('MERGE'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd2'),
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
    return merges;
  }

  Future<void> select(WidgetTester tester, List<String> names) async {
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    for (final name in names) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('bulk delete deletes the profile\'s own and hides another\'s, '
      'and Undo restores both', (tester) async {
    await seedSite(db, 'mine', owner: 'd2', shared: true, name: 'Alpha');
    await seedSite(db, 'theirs', owner: 'd1', shared: true, name: 'Bravo');
    await pump(tester);
    await select(tester, ['Alpha', 'Bravo']);
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 site will be deleted.'), findsOneWidget);
    expect(
      find.textContaining(
        '1 of them is shared with other profiles and will be deleted for '
        'everyone.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '1 shared site will be removed from your profile only.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete').hitTestable().last);
    await tester.pumpAndSettle();

    final repository = SiteRepository();
    expect(await repository.getSiteById('mine'), isNull);
    expect(await repository.getSiteById('theirs'), isNotNull);
    expect((await db.select(db.siteHides).get()).single.siteId, 'theirs');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await repository.getSiteById('mine'), isNotNull);
    expect(await db.select(db.siteHides).get(), isEmpty);
  });

  testWidgets('merge refuses two sites another profile owns', (tester) async {
    await seedSite(db, 'x', owner: 'd1', shared: true, name: 'Alpha');
    await seedSite(db, 'y', owner: 'd1', shared: true, name: 'Bravo');
    await seedSite(db, 'z', owner: 'd2', name: 'Charlie');
    final merges = await pump(tester);
    await select(tester, ['Alpha', 'Bravo', 'Charlie']);
    await tester.tap(find.byIcon(Icons.merge_type));
    await tester.pumpAndSettle();

    expect(merges, isEmpty);
    expect(
      find.textContaining('Only one of the selected sites can belong'),
      findsOneWidget,
    );
  });

  testWidgets('merge keeps another profile\'s site as the survivor', (
    tester,
  ) async {
    await seedSite(db, 'mine', owner: 'd2', name: 'Alpha');
    await seedSite(db, 'theirs', owner: 'd1', shared: true, name: 'Bravo');
    final merges = await pump(tester);
    await select(tester, ['Alpha', 'Bravo']);
    await tester.tap(find.byIcon(Icons.merge_type));
    await tester.pumpAndSettle();

    expect(merges.single.first, 'theirs');
  });
}
