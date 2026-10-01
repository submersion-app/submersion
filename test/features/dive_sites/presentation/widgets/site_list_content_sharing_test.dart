import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
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
  Future<List<List<String>>> pump(
    WidgetTester tester, {
    SiteRepository? repository,
    FailingProfileHides? hides,
    bool profilesUncountable = false,
  }) async {
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
          if (repository != null)
            siteRepositoryProvider.overrideWithValue(repository),
          if (hides != null)
            profileHidesRepositoryProvider.overrideWithValue(hides),
          if (profilesUncountable)
            allDiversProvider.overrideWith(
              (ref) async => throw StateError('no divers'),
            ),
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

    // The site list's own line states the delete count, with its Undo
    // window; the shared-item lines do not repeat it.
    expect(find.textContaining('1 site will be deleted.'), findsNothing);
    expect(
      find.textContaining('Are you sure you want to delete 1 site?'),
      findsOneWidget,
    );
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

  Future<void> confirmBulkDelete(
    WidgetTester tester,
    List<String> names,
  ) async {
    await select(tester, names);
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  group('a hide that fails (issue #2677)', () {
    const tryAgain = 'Something went wrong. Please try again.';

    testWidgets('keeps the delete and its Undo, and says to try again', (
      tester,
    ) async {
      await seedSite(db, 'mine', owner: 'd2', shared: true, name: 'Alpha');
      await seedSite(db, 'theirs', owner: 'd1', shared: true, name: 'Bravo');
      await pump(tester, hides: FailingProfileHides()..failHide = true);
      await confirmBulkDelete(tester, ['Alpha', 'Bravo']);

      final repository = SiteRepository();
      expect(await repository.getSiteById('mine'), isNull);
      expect(await db.select(db.siteHides).get(), isEmpty);
      expect(find.text('Deleted 1 site · $tryAgain'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await repository.getSiteById('mine'), isNotNull);
      expect(find.text('Sites restored'), findsOneWidget);
    });

    testWidgets('with nothing deleted says only to try again, with no Undo', (
      tester,
    ) async {
      await seedSite(db, 'theirs', owner: 'd1', shared: true, name: 'Bravo');
      await pump(tester, hides: FailingProfileHides()..failHide = true);
      await confirmBulkDelete(tester, ['Bravo']);

      expect(await db.select(db.siteHides).get(), isEmpty);
      expect(find.text(tryAgain), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('after the hide was written still lets Undo unhide it', (
      tester,
    ) async {
      await seedSite(db, 'mine', owner: 'd2', shared: true, name: 'Alpha');
      await seedSite(db, 'theirs', owner: 'd1', shared: true, name: 'Bravo');
      await pump(tester, hides: FailingProfileHides()..failAfterHide = true);
      await confirmBulkDelete(tester, ['Alpha', 'Bravo']);
      expect(find.text('Deleted 1 site · $tryAgain'), findsOneWidget);
      expect(await db.select(db.siteHides).get(), hasLength(1));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await db.select(db.siteHides).get(), isEmpty);
      expect(await SiteRepository().getSiteById('mine'), isNotNull);
    });

    testWidgets('a failed restore in Undo says to try again and offers '
        'Undo again', (tester) async {
      await seedSite(db, 'mine', owner: 'd2', name: 'Alpha');
      final repository = _UnrestorableSites();
      await pump(tester, repository: repository);
      await confirmBulkDelete(tester, ['Alpha']);
      expect(await SiteRepository().getSiteById('mine'), isNull);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text(tryAgain), findsOneWidget);
      expect(find.text('Sites restored'), findsNothing);

      repository.fail = false;
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await SiteRepository().getSiteById('mine'), isNotNull);
      expect(find.text('Sites restored'), findsOneWidget);
    });

    testWidgets('says so once the list has closed', (tester) async {
      await seedSite(db, 'mine', owner: 'd2', shared: true, name: 'Alpha');
      await seedSite(db, 'theirs', owner: 'd1', shared: true, name: 'Bravo');
      final gate = Completer<void>();
      await pump(
        tester,
        hides: FailingProfileHides()
          ..failHide = true
          ..hideGate = gate,
      );
      await confirmBulkDelete(tester, ['Alpha', 'Bravo']);
      GoRouter.of(
        tester.element(find.byType(SiteListContent)),
      ).go('/sites/merge', extra: <String>[]);
      await tester.pumpAndSettle();
      expect(find.byType(SiteListContent), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Deleted 1 site · $tryAgain'), findsOneWidget);
    });

    testWidgets('in Undo keeps the hide and says to try again', (tester) async {
      await seedSite(db, 'theirs', owner: 'd1', shared: true, name: 'Bravo');
      final hides = FailingProfileHides();
      await pump(tester, hides: hides);
      await confirmBulkDelete(tester, ['Bravo']);
      expect(await db.select(db.siteHides).get(), hasLength(1));

      hides.failUnhide = true;
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await db.select(db.siteHides).get(), hasLength(1));
      expect(find.text(tryAgain), findsOneWidget);
      expect(find.text('Sites restored'), findsNothing);

      hides.failUnhide = false;
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await db.select(db.siteHides).get(), isEmpty);
      expect(find.text('Sites restored'), findsOneWidget);
    });
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

  testWidgets('a failed read before the bulk delete says so and deletes '
      'nothing', (tester) async {
    await seedSite(db, 'mine', owner: 'd2', name: 'Alpha');
    await pump(tester, repository: _UnreadableSites());
    await select(tester, ['Alpha']);
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(await SiteRepository().getSiteById('mine'), isNotNull);
  });

  testWidgets('a failed read before a merge says so and merges nothing', (
    tester,
  ) async {
    await seedSite(db, 'a', owner: 'd2', name: 'Alpha');
    await seedSite(db, 'b', owner: 'd2', name: 'Bravo');
    final merges = await pump(tester, repository: _UnreadableSites());
    await select(tester, ['Alpha', 'Bravo']);
    await tester.tap(find.byIcon(Icons.merge_type));
    await tester.pumpAndSettle();

    expect(merges, isEmpty);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  // Failing open, the dialog left out the "deleted for everyone" line for
  // the owner's shared site (issue #2682).
  testWidgets('an unreadable sharing context before the bulk delete says so '
      'and deletes nothing', (tester) async {
    await seedSite(db, 'mine', owner: 'd2', shared: true, name: 'Alpha');
    await pump(tester, profilesUncountable: true);
    await select(tester, ['Alpha']);
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(await SiteRepository().getSiteById('mine'), isNotNull);
  });

  testWidgets('an unreadable sharing context before a merge says so and '
      'merges nothing', (tester) async {
    await seedSite(db, 'a', owner: 'd2', name: 'Alpha');
    await seedSite(db, 'b', owner: 'd1', shared: true, name: 'Bravo');
    final merges = await pump(tester, profilesUncountable: true);
    await select(tester, ['Alpha', 'Bravo']);
    await tester.tap(find.byIcon(Icons.merge_type));
    await tester.pumpAndSettle();

    expect(merges, isEmpty);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}

/// A site repository whose re-create fails, as a database error would, so
/// an Undo cannot bring a deleted site back.
class _UnrestorableSites extends SiteRepository {
  bool fail = true;

  @override
  Future<DiveSite> createSite(
    DiveSite site, {
    SiteClassification? classification,
  }) async {
    if (fail) throw StateError('database unavailable');
    return super.createSite(site, classification: classification);
  }
}

/// A site repository whose lookup by ids fails, as a database error would.
class _UnreadableSites extends SiteRepository {
  @override
  Future<List<DiveSite>> getSitesByIds(List<String> ids) async =>
      throw StateError('database unavailable');
}
