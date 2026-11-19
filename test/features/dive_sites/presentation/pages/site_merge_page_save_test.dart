import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' hide Diver, DiveSite;
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/location_section.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_routes.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_merge_page.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A position that answers only when [answer] completes.
class _SlowFix implements LocationService {
  final answer = Completer<void>();

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    await answer.future;
    return const LocationResult(latitude: 17.3, longitude: -87.5);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A geocoder whose every lookup finds [place].
class _Finds implements LocationService {
  _Finds(this.place);

  final PlaceLookup place;

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async => place;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A species store that cannot write a site's expected species.
class _UnwritableSpecies extends SpeciesRepository {
  @override
  Future<void> removeAllExpectedSpeciesForSite(String siteId) async =>
      throw StateError('disk full');
}

/// An elevation of ten metres per degree of latitude, each held until its
/// gate, when one is set, completes.
class _GatedElevation extends ElevationService {
  final gates = <double, Completer<void>>{};

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    await gates[latitude]?.future;
    return latitude * 10;
  }
}

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
    List<Override> extra = const [],
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
          ...extra,
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

  // A site deleted since the list's selection (by another device's sync,
  // say): the page shows the sites still stored, and merges those.
  testWidgets('a merge leaves out a site gone since it was selected', (
    tester,
  ) async {
    await seedSite(db, 'a', owner: 'd2', name: 'Salt Pier');
    await seedSite(db, 'b', owner: 'd2', name: 'Salt Pier North');
    final result = await pump(tester, const ['gone', 'a', 'b'], active: 'd2');

    await tester.tap(find.text(l.forms_save).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l.diveSites_edit_merge_confirmBody(2)), findsOneWidget);
    await tester.tap(find.text(l.diveSites_edit_appBar_merge).last);
    await tester.pumpAndSettle();

    final merged = await result;
    expect(merged, isA<SiteMergeResult>());
    expect((merged! as SiteMergeResult).survivorId, 'a');
    expect(await stored('a'), isTrue);
    expect(await stored('b'), isFalse);
  });

  // What a merge stores (final review): the chosen candidates, the chosen
  // country's code, and the expected species as the page shows them.
  testWidgets('a merge stores the chosen values and the shown species', (
    tester,
  ) async {
    final sites = SiteRepository();
    await sites.createSite(
      const DiveSite(
        id: 'a',
        name: 'Salt Pier',
        country: 'Mexico',
        countryCode: 'MX',
        region: 'Yucatan',
        difficulty: SiteDifficulty.beginner,
        altitude: 10,
        isShared: true,
      ),
    );
    await sites.createSite(
      const DiveSite(
        id: 'b',
        name: 'Salt Pier North',
        // A name the country table cannot read: only the stored code
        // carries it.
        country: 'The Cayes',
        countryCode: 'BZ',
        region: 'Turneffe',
        difficulty: SiteDifficulty.advanced,
      ),
    );
    final species = SpeciesRepository();
    final turtle = await species.createSpecies(
      commonName: 'Turtle',
      category: SpeciesCategory.fish,
    );
    final ray = await species.createSpecies(
      commonName: 'Ray',
      category: SpeciesCategory.fish,
    );
    await species.addExpectedSpecies(siteId: 'a', speciesId: turtle.id);
    await species.addExpectedSpecies(siteId: 'b', speciesId: ray.id);
    await pump(tester, const ['a', 'b'], active: 'd2');

    final identity = tester.widget<IdentitySection>(
      find.byType(IdentitySection),
    );
    identity.mergeExtras!('country')!.onCycle();
    identity.mergeExtras!('region')!.onCycle();
    tester
        .widget<DiveInfoSection>(find.byType(DiveInfoSection))
        .difficultyExtras!
        .onCycle();
    await tester.pump();
    final life = tester.widget<LifeNotesSection>(find.byType(LifeNotesSection));
    life.onRemoveSpecies(life.species.firstWhere((s) => s.id == turtle.id));
    await tester.pump();

    await saveAndMerge(tester);

    final merged = (await sites.getSiteById('a'))!;
    expect(merged.name, 'Salt Pier');
    expect(merged.country, 'The Cayes');
    expect(merged.countryCode, 'BZ');
    expect(merged.region, 'Turneffe');
    expect(merged.difficulty, SiteDifficulty.advanced);
    expect(merged.altitude, 10);
    // The survivor's sharing comes through the merge (issue #2151).
    expect(merged.isShared, isTrue);
    expect(
      [
        for (final e in await species.getExpectedSpeciesForSite('a'))
          e.speciesId,
      ],
      [ray.id],
    );
  });

  // The altitude filled from the coordinates is the chosen position's: an
  // answer for a position the diver has since cycled away from fills
  // nothing (code review), as on the site page's Location card.
  testWidgets(
    'an altitude found for coordinates since cycled away is dropped',
    (tester) async {
      final sites = SiteRepository();
      await sites.createSite(
        const DiveSite(id: 'a', name: 'Salt Pier', location: GeoPoint(10, 10)),
      );
      await sites.createSite(
        const DiveSite(
          id: 'b',
          name: 'Salt Pier N',
          location: GeoPoint(20, 20),
        ),
      );
      final elevation = _GatedElevation();
      final first = elevation.gates[10] = Completer<void>();
      await pump(
        tester,
        const ['a', 'b'],
        active: 'd2',
        extra: [elevationServiceProvider.overrideWithValue(elevation)],
      );
      LocationSection section() =>
          tester.widget<LocationSection>(find.byType(LocationSection));

      // The first site's position is asked about, and held.
      await tester.pump(const Duration(seconds: 1));
      section().coordinatesExtras!.onCycle();
      await tester.pump();
      first.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(section().altitudeController.text, '200');
    },
  );

  // The merge is done once the repository returns: a species write that
  // fails after it still hands the list the merge, so Undo is offered and
  // no second Save is asked of sites already merged (code review).
  testWidgets('a merge whose species write fails still returns the merge', (
    tester,
  ) async {
    await seedSite(db, 'a', owner: 'd2', name: 'Salt Pier');
    await seedSite(db, 'b', owner: 'd2', name: 'Salt Pier North');
    final result = await pump(
      tester,
      const ['a', 'b'],
      active: 'd2',
      extra: [
        speciesRepositoryProvider.overrideWithValue(_UnwritableSpecies()),
      ],
    );

    await saveAndMerge(tester);

    expect(find.text('SITES'), findsOneWidget);
    final merged = await result;
    expect((merged! as SiteMergeResult).survivorId, 'a');
    expect((merged as SiteMergeResult).snapshot, isNotNull);
    expect(await stored('b'), isFalse);
  });

  // Look up on the merge page carries the geocoder's country code to the
  // merged site (issue #4426), and a country typed afterwards is read again.
  group("Look up's country code", () {
    // A name the country table cannot read: only the geocoder's code
    // carries it.
    const cayes = PlaceLookup(country: 'The Cayes', countryCode: 'BZ');

    Future<void> lookUp(WidgetTester tester) async {
      final sites = SiteRepository();
      await sites.createSite(
        const DiveSite(id: 'a', name: 'Hole', location: GeoPoint(17.3, -87.5)),
      );
      await sites.createSite(const DiveSite(id: 'b', name: 'Hole North'));
      await pump(
        tester,
        const ['a', 'b'],
        active: 'd2',
        extra: [locationServiceProvider.overrideWithValue(_Finds(cayes))],
      );
      final button = find.text(l.diveSites_edit_gps_lookupFromCoordinates);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    TextEditingController country(WidgetTester tester) => tester
        .widget<IdentitySection>(find.byType(IdentitySection))
        .countryController;

    testWidgets('a looked-up country saves the geocoder code', (tester) async {
      await lookUp(tester);
      expect(country(tester).text, 'The Cayes');

      await saveAndMerge(tester);

      final merged = (await SiteRepository().getSiteById('a'))!;
      expect(merged.country, 'The Cayes');
      expect(merged.countryCode, 'BZ');
    });

    testWidgets('a country typed after the lookup is read again', (
      tester,
    ) async {
      await lookUp(tester);
      country(tester).text = 'Mexico';
      await tester.pump();

      await saveAndMerge(tester);

      final merged = (await SiteRepository().getSiteById('a'))!;
      expect(merged.country, 'Mexico');
      expect(merged.countryCode, 'MX');
    });
  });

  // The fields are seeded in the active locale's decimal separator and read
  // back in it (#1091): an untouched merge under a grouping-dot locale
  // stores the survivor's numbers unchanged (code review).
  testWidgets('an untouched merge under de keeps depths and altitude', (
    tester,
  ) async {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = previousLocale);
    final sites = SiteRepository();
    await sites.createSite(
      const DiveSite(
        id: 'a',
        name: 'Walchensee',
        minDepth: 12.5,
        maxDepth: 30,
        altitude: 1500,
      ),
    );
    await sites.createSite(const DiveSite(id: 'b', name: 'Walchensee Nord'));
    await pump(tester, const ['a', 'b'], active: 'd2');
    expect(
      tester
          .widget<DiveInfoSection>(find.byType(DiveInfoSection))
          .minDepthController
          .text,
      '12,5',
    );

    await saveAndMerge(tester);

    final merged = (await sites.getSiteById('a'))!;
    expect(merged.minDepth, closeTo(12.5, 0.001));
    expect(merged.maxDepth, closeTo(30, 0.001));
    expect(merged.altitude, closeTo(1500, 0.001));
  });

  // A position that arrives once the diver has left the page changes
  // nothing and throws nothing (final review).
  testWidgets('Use my location answering after the page closed is dropped', (
    tester,
  ) async {
    await seedSite(db, 'a', owner: 'd2', name: 'Salt Pier');
    await seedSite(db, 'b', owner: 'd2', name: 'Salt Pier North');
    final fix = _SlowFix();
    await pump(
      tester,
      const ['a', 'b'],
      active: 'd2',
      extra: [locationServiceProvider.overrideWithValue(fix)],
    );

    await tester.ensureVisible(find.text(l.diveSites_edit_gps_useMyLocation));
    await tester.tap(find.text(l.diveSites_edit_gps_useMyLocation));
    await tester.pump();
    Navigator.of(tester.element(find.byType(SiteMergePage))).pop();
    await tester.pumpAndSettle();
    expect(find.text('SITES'), findsOneWidget);

    fix.answer.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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

    // Refused at Save: nothing to confirm (final review).
    await tester.tap(find.text(l.forms_save).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

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
