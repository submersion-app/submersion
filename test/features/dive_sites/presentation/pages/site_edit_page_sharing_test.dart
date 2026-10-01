import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Editing another profile's shared site: sharing is locked and the delete
/// action only removes the site from the active profile (issue #2594).
void main() {
  setUp(() {
    serveFakeHost('api.open-meteo.com');
  });

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
    await seedSite(db, 'pier', owner: 'd1', shared: true, name: 'Salt Pier');
    await seedDive(db, 'b1', diver: 'd2', siteId: 'pier');
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester, {
    required String active,
    VoidCallback? onDeleted,
    bool profileUnreadable = false,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith(
            (_) async =>
                profileUnreadable ? throw StateError('no profile') : active,
          ),
          shareByDefaultProvider.overrideWith((_) async => false),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: 'pier',
              embedded: true,
              onSaved: (id) {},
              onCancel: () {},
              onDeleted: onDeleted ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLifeSection(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('shared'),
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('shared'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Share with all dive profiles'),
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('another profile gets Remove, not Delete', (tester) async {
    await pump(tester, active: 'd2');
    expect(find.widgetWithIcon(IconButton, Icons.delete), findsNothing);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
    );
    await tester.pumpAndSettle();
    expect(find.text("Remove 'Salt Pier' from your profile?"), findsOneWidget);
    expect(find.textContaining('1 of your dives stays linked'), findsOneWidget);
  });

  // Read as "no profile", the page offered another profile's site its
  // Delete and unlocked its sharing (issue #2682). Ownership is unknown,
  // not refused, so the lock names no owner.
  testWidgets('an unreadable profile offers neither action and locks '
      'sharing', (tester) async {
    await pump(tester, active: 'd2', profileUnreadable: true);
    expect(find.widgetWithIcon(IconButton, Icons.delete), findsNothing);
    expect(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      findsNothing,
    );
    await openLifeSection(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('Only Alice can change sharing'), findsNothing);
  });

  testWidgets('another profile cannot change sharing', (tester) async {
    await pump(tester, active: 'd2');
    await openLifeSection(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('Only Alice can change sharing'), findsOneWidget);
  });

  testWidgets('the owner deletes, warned about other profiles\' dives', (
    tester,
  ) async {
    await pump(tester, active: 'd1');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete shared site?'), findsOneWidget);
    expect(
      find.textContaining('1 dive in another profile will lose this site.'),
      findsOneWidget,
    );
  });

  testWidgets('the owner can change sharing', (tester) async {
    await pump(tester, active: 'd1');
    await openLifeSection(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });

  testWidgets('removing hides it for this profile, closes, and Undo restores', (
    tester,
  ) async {
    var closed = 0;
    await pump(tester, active: 'd2', onDeleted: () => closed++);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(closed, 1);
    final hides = await db.select(db.siteHides).get();
    expect((hides.single.siteId, hides.single.diverId), ('pier', 'd2'));
    expect(find.text('Removed from your profile'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await db.select(db.siteHides).get(), isEmpty);
  });

  testWidgets('an owner whose site changed hands meanwhile is refused', (
    tester,
  ) async {
    var closed = 0;
    await pump(tester, active: 'd1', onDeleted: () => closed++);
    // Another device handed the site to d2 after the page loaded.
    await db.customStatement(
      "UPDATE dive_sites SET diver_id = 'd2' WHERE id = 'pier'",
    );
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Only its owner can delete this site'), findsOneWidget);
    expect(closed, 0);
    expect(
      await (db.select(
        db.diveSites,
      )..where((t) => t.id.equals('pier'))).getSingleOrNull(),
      isNotNull,
    );
  });

  testWidgets('a merge the repository refuses stays on the page and says so', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await seedSite(db, 'mine', owner: 'd2', name: 'My Pier');
    // 'pier' (seeded above) is Alice's: Bob may not merge it away.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'd2'),
          shareByDefaultProvider.overrideWith((_) async => false),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/merge',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('SITES')),
                routes: [
                  GoRoute(
                    path: 'merge',
                    builder: (_, _) =>
                        const SiteEditPage(mergeSiteIds: ['mine', 'pier']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').first);
    // The save spinner runs while the confirmation is open: no settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Merge').last);
    await tester.pumpAndSettle();

    expect(find.text('SITES'), findsNothing);
    expect(find.text('Only its owner can delete this site'), findsOneWidget);
    expect(
      await (db.select(
        db.diveSites,
      )..where((t) => t.id.equals('pier'))).getSingleOrNull(),
      isNotNull,
    );
  });
}
