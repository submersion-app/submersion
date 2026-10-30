import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';

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
    FailingProfileHides? hides,
    GatedActiveProfile? activeProfile,
    bool profileUnreadable = false,
    ItemSharesRepository? shares,
    String siteId = 'pier',
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
            (_) =>
                activeProfile?.read() ??
                (profileUnreadable
                    ? Future<String?>.error(StateError('no profile'))
                    : Future.value(active)),
          ),
          shareByDefaultProvider.overrideWith((_) async => false),
          if (hides != null)
            profileHidesRepositoryProvider.overrideWithValue(hides),
          if (shares != null)
            itemSharesRepositoryProvider.overrideWithValue(shares),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: siteId,
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
      find.text('Shared with'),
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

  testWidgets('while a profile switch re-reads the profile, offers neither '
      'Delete nor Remove (issue #2677 review)', (tester) async {
    final activeProfile = GatedActiveProfile.settled('d1');
    await pump(tester, active: 'd1', activeProfile: activeProfile);
    expect(find.widgetWithIcon(IconButton, Icons.delete), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(SiteEditPage)),
    ).invalidate(validatedCurrentDiverIdProvider);
    await tester.pump();
    expect(find.widgetWithIcon(IconButton, Icons.delete), findsNothing);
    expect(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      findsNothing,
    );

    activeProfile.settle('d2');
    await tester.pumpAndSettle();
    expect(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      findsOneWidget,
    );
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
    expect(tester.widget<SharingTile>(find.byType(SharingTile)).onTap, isNull);
    expect(find.text('Only Alice can change sharing'), findsNothing);
  });

  testWidgets('another profile cannot change sharing', (tester) async {
    await pump(tester, active: 'd2');
    await openLifeSection(tester);
    expect(tester.widget<SharingTile>(find.byType(SharingTile)).onTap, isNull);
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

  testWidgets('a shared site library site offers no Remove to a profile '
      'outside the library (issue #2151)', (tester) async {
    await seedSite(db, 'lib-site', name: 'Library Reef');
    await db.customStatement(
      "UPDATE dive_sites SET shared_library_id = 'L' WHERE id = 'lib-site'",
    );
    await pump(tester, active: 'd2', siteId: 'lib-site');
    expect(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      findsNothing,
    );
  });

  testWidgets('a delete before the share rows load still warns about a site '
      'shared by name (issue #2151)', (tester) async {
    await db.customStatement(
      "UPDATE dive_sites SET is_shared = 0 WHERE id = 'pier'",
    );
    // The page's own read is held open; the delete reads afresh.
    final shares = _GatedShares(const ItemSharing(profileIds: {'d2'}));
    await pump(tester, active: 'd1', shares: shares);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete shared site?'), findsOneWidget);
  });

  testWidgets('the sharing field stays locked until the share rows are read '
      '(issue #2151)', (tester) async {
    final shares = _GatedShares();
    await pump(tester, active: 'd1', shares: shares);
    await openLifeSection(tester);
    expect(tester.widget<SharingTile>(find.byType(SharingTile)).onTap, isNull);

    shares.gate.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<SharingTile>(find.byType(SharingTile)).onTap,
      isNotNull,
    );
  });

  testWidgets('the owner can change sharing', (tester) async {
    await pump(tester, active: 'd1');
    await openLifeSection(tester);
    expect(
      tester.widget<SharingTile>(find.byType(SharingTile)).onTap,
      isNotNull,
    );
  });

  // The edit page is the one place sharing changes (#3766), so a refused
  // change says so rather than passing silently.
  testWidgets('a sharing change the repository refuses says who may change '
      'it', (tester) async {
    final shares = FakeItemShares.everyone(['pier'])..refuseSet = true;
    String? saved;
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'd1'),
          shareByDefaultProvider.overrideWith((_) async => false),
          itemSharesRepositoryProvider.overrideWithValue(shares),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: 'pier',
              embedded: true,
              onSaved: (id) => saved = id,
              onCancel: () {},
              onDeleted: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openLifeSection(tester);
    await tester.tap(find.byType(SharingTile));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Bob')),
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(shares.setCalls, [
      ('pier', const ItemSharing(profileIds: {'d2'})),
    ]);
    // The profile acting now, which the repository checks (issue #2151).
    expect(shares.setActingDivers, ['d1']);
    expect(saved, 'pier');
    expect(
      find.text('Only another profile can change sharing'),
      findsOneWidget,
    );
  });

  testWidgets('on the full page, a refused sharing change closes the page and '
      'says who may change it instead of Site updated', (tester) async {
    final shares = FakeItemShares.everyone(['pier'])..refuseSet = true;
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/edit'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => const SiteEditPage(siteId: 'pier'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'd1'),
          shareByDefaultProvider.overrideWith((_) async => false),
          itemSharesRepositoryProvider.overrideWithValue(shares),
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
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await openLifeSection(tester);
    await tester.tap(find.byType(SharingTile));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Bob')),
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(shares.setCalls, [
      ('pier', const ItemSharing(profileIds: {'d2'})),
    ]);
    expect(find.text('open'), findsOneWidget, reason: 'the page closed');
    expect(
      find.text('Only another profile can change sharing'),
      findsOneWidget,
    );
    expect(find.text('Site updated'), findsNothing);
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

  testWidgets('a failed remove stays on the page and says to try again', (
    tester,
  ) async {
    var closed = 0;
    await pump(
      tester,
      active: 'd2',
      onDeleted: () => closed++,
      hides: FailingProfileHides()..failHide = true,
    );
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(closed, 0);
    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Removed from your profile'), findsNothing);
  });

  testWidgets('a failed Undo keeps the hide, says to try again and offers '
      'Undo again', (tester) async {
    final hides = FailingProfileHides();
    await pump(tester, active: 'd2', hides: hides);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    hides.failUnhide = true;
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await db.select(db.siteHides).get(), hasLength(1));
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );

    hides.failUnhide = false;
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await db.select(db.siteHides).get(), isEmpty);
  });

  testWidgets('a site already hidden here offers Unhide, not Remove (#2679)', (
    tester,
  ) async {
    await ProfileHidesRepository().hide(SharedItemKind.site, 'pier', 'd2');
    var closed = 0;
    await pump(tester, active: 'd2', onDeleted: () => closed++);
    expect(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Show in my profile'));
    await tester.pumpAndSettle();

    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(closed, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      findsOneWidget,
    );
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

/// Holds the share-row read open until [gate] completes.
class _GatedShares extends FakeItemShares {
  _GatedShares([ItemSharing pier = ItemSharing.all]) : super({'pier': pier});

  final gate = Completer<void>();

  @override
  Future<Set<String>> storedProfileIds(SharedItemKind kind, String id) async {
    await gate.future;
    return super.storedProfileIds(kind, id);
  }
}
