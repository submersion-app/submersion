import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveSitesCompanion, DiversCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

const _source = DiveSite(
  id: 'site-1',
  name: 'Salt Pier',
  description: 'Pier pilings and a sandy slope',
  location: GeoPoint(12.0818, -68.2805),
  minDepth: 5,
  maxDepth: 18,
  difficulty: SiteDifficulty.intermediate,
  waterType: WaterType.salt,
  country: 'Bonaire',
  region: 'Caribbean',
  city: 'Kralendijk',
  island: 'Bonaire',
  bodyOfWater: 'Caribbean Sea',
  rating: 4,
  notes: 'Ask the pier office first',
  hazards: 'Boat traffic',
  accessNotes: 'Shore entry down the stairs',
  mooringNumber: '7',
  parkingInfo: 'Gravel lot',
  altitude: 300,
  entryMethods: [EntryMethod.shore],
  exitMethods: [EntryMethod.ladder],
);

/// Duplicating a site (issue #3575): the form starts as a new, unsaved site
/// carrying everything from the original, and nothing is written until Save.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  late String tagId;
  late String speciesId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final now = DateTime(2026, 10, 23);
    tagId = (await TagRepository().createTag(
      Tag(
        id: 'tag-1',
        name: 'Liveaboard',
        createdAt: now,
        updatedAt: now,
        scopes: const {TagScope.sites},
      ),
    )).id;
    await SiteRepository().createSite(
      _source,
      classification: SiteClassification(typeIds: ['wall'], tagIds: [tagId]),
    );
    final species = SpeciesRepository();
    speciesId = (await species.createSpecies(
      commonName: 'Seahorse',
      category: SpeciesCategory.fish,
    )).id;
    await species.addExpectedSpecies(siteId: 'site-1', speciesId: speciesId);
    await SiteFeatureRepository().addFeature(
      siteId: 'site-1',
      typeName: 'mooring',
      name: 'North ball',
      latitude: 12.0819,
      longitude: -68.2806,
    );
  });

  tearDown(tearDownTestDatabase);

  // Riverpod does not re-export its sealed Override type (see testApp).
  List<dynamic> overrides({bool shareByDefault = false, String? diverId}) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    allDiversProvider.overrideWith((_) async => const <Diver>[]),
    shareByDefaultProvider.overrideWith((_) async => shareByDefault),
    validatedCurrentDiverIdProvider.overrideWith((_) async => diverId),
  ];

  Future<void> pumpDuplicate(
    WidgetTester tester, {
    String sourceId = 'site-1',
    void Function(String)? onSaved,
    VoidCallback? onCancel,
    bool shareByDefault = false,
    bool sourceLoaded = false,
    String? diverId,
    List<dynamic> extraOverrides = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ...overrides(shareByDefault: shareByDefault, diverId: diverId),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    // Opened from its detail page, the original is already loaded, so the
    // form fills in its first frame rather than after a database read.
    if (sourceLoaded) {
      await tester.runAsync(
        () => container.read(siteProvider(sourceId).future),
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SiteEditPage(
              duplicateOfId: sourceId,
              embedded: true,
              onSaved: onSaved ?? (_) {},
              onCancel: onCancel ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> saveDuplicate(
    WidgetTester tester, {
    bool sourceLoaded = false,
    String? diverId,
  }) async {
    String? savedId;
    await pumpDuplicate(
      tester,
      onSaved: (id) => savedId = id,
      sourceLoaded: sourceLoaded,
      diverId: diverId,
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(savedId, isNotNull, reason: 'Save did not finish');
    expect(savedId, isNot('site-1'));
    return savedId!;
  }

  testWidgets('saving writes a new site carrying every field of the original', (
    tester,
  ) async {
    final copyId = await saveDuplicate(tester);

    final copy = (await tester.runAsync(
      () => SiteRepository().getSiteById(copyId),
    ))!;
    expect(copy.name, 'Salt Pier (copy)');
    expect(copy.description, _source.description);
    expect(copy.location, _source.location);
    expect(copy.minDepth, _source.minDepth);
    expect(copy.maxDepth, _source.maxDepth);
    expect(copy.difficulty, _source.difficulty);
    expect(copy.waterType, _source.waterType);
    expect(copy.country, _source.country);
    expect(copy.region, _source.region);
    expect(copy.city, _source.city);
    expect(copy.island, _source.island);
    expect(copy.bodyOfWater, _source.bodyOfWater);
    expect(copy.rating, _source.rating);
    expect(copy.notes, _source.notes);
    expect(copy.hazards, _source.hazards);
    expect(copy.accessNotes, _source.accessNotes);
    expect(copy.mooringNumber, _source.mooringNumber);
    expect(copy.parkingInfo, _source.parkingInfo);
    expect(copy.altitude, _source.altitude);
    expect(copy.entryMethods, _source.entryMethods);
    expect(copy.exitMethods, _source.exitMethods);
  });

  testWidgets('the copy gets the original\'s types, tags and species', (
    tester,
  ) async {
    final copyId = await saveDuplicate(tester);

    final classification = SiteClassificationRepository();
    final types = await tester.runAsync(
      () => classification.getTypesForSite(copyId),
    );
    final tags = await tester.runAsync(
      () => classification.getTagsForSite(copyId),
    );
    final species = await tester.runAsync(
      () => SpeciesRepository().getExpectedSpeciesForSite(copyId),
    );
    expect(types!.map((t) => t.id), ['wall']);
    expect(tags!.map((t) => t.id), [tagId]);
    expect(species!.map((s) => s.speciesId), [speciesId]);
  });

  testWidgets('another profile\'s shared site copies only my own types and '
      'tags', (tester) async {
    // Like an equipment clone (#2046): the owner's custom types and tags
    // must not come along onto the copy the active diver makes.
    final now = DateTime(2026, 10, 23);
    late String ownerTypeId;
    late String myTypeId;
    await tester.runAsync(() async {
      for (final id in ['me', 'owner']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: now.millisecondsSinceEpoch,
                updatedAt: now.millisecondsSinceEpoch,
              ),
            );
      }
      // The repository suffixes each id, so keep the ones it returns.
      final types = SiteTypeRepository();
      Future<String> custom(String name, String owner) async =>
          (await types.createSiteType(
            SiteTypeEntity(
              id: '',
              diverId: owner,
              name: name,
              createdAt: now,
              updatedAt: now,
            ),
          )).id;
      ownerTypeId = await custom('Owner reef', 'owner');
      myTypeId = await custom('My reef', 'me');
      await TagRepository().createTag(
        Tag(
          id: 'tag-owner',
          diverId: 'owner',
          name: 'Owner only',
          createdAt: now,
          updatedAt: now,
          scopes: const {TagScope.sites},
        ),
      );
      final classification = SiteClassificationRepository();
      await classification.replaceTypes('site-1', [
        'wall',
        ownerTypeId,
        myTypeId,
      ]);
      await classification.replaceTags('site-1', [tagId, 'tag-owner']);
    });

    final copyId = await saveDuplicate(tester, diverId: 'me');

    final classification = SiteClassificationRepository();
    final types = await tester.runAsync(
      () => classification.getTypesForSite(copyId),
    );
    final tags = await tester.runAsync(
      () => classification.getTagsForSite(copyId),
    );
    expect(types!.map((t) => t.id), unorderedEquals(['wall', myTypeId]));
    expect(tags!.map((t) => t.id), [tagId]);
  });

  testWidgets('a Save before the types load still copies them', (tester) async {
    final stored = Completer<List<SiteTypeEntity>>();
    String? savedId;
    await pumpDuplicate(
      tester,
      onSaved: (id) => savedId = id,
      extraOverrides: [
        siteTypesForSiteProvider('site-1').overrideWith((_) => stored.future),
      ],
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    stored.complete(
      (await tester.runAsync(
        () => SiteClassificationRepository().getTypesForSite('site-1'),
      ))!,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(savedId, isNotNull, reason: 'Save did not finish');
    final types = await tester.runAsync(
      () => SiteClassificationRepository().getTypesForSite(savedId!),
    );
    expect(types!.map((t) => t.id), ['wall']);
  });

  testWidgets('tags that fail to load still let the copy save', (tester) async {
    String? savedId;
    await pumpDuplicate(
      tester,
      onSaved: (id) => savedId = id,
      extraOverrides: [
        tagsForSiteProvider(
          'site-1',
        ).overrideWith((_) async => throw StateError('db locked')),
      ],
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(savedId, isNotNull, reason: 'Save did not finish');
    final copy = (await tester.runAsync(
      () => SiteRepository().getSiteById(savedId!),
    ))!;
    expect(copy.name, 'Salt Pier (copy)');
  });

  testWidgets('the copy gets the original\'s seascape features', (
    tester,
  ) async {
    final copyId = await saveDuplicate(tester);

    final features = await tester.runAsync(
      () => SiteFeatureRepository().getFeaturesForSite(copyId),
    );
    expect(features!.single.typeName, 'mooring');
    expect(features.single.name, 'North ball');
  });

  testWidgets('the original is left as it was', (tester) async {
    await saveDuplicate(tester);

    final original = (await tester.runAsync(
      () => SiteRepository().getSiteById('site-1'),
    ))!;
    expect(original.name, 'Salt Pier');
    final features = await tester.runAsync(
      () => SiteFeatureRepository().getFeaturesForSite('site-1'),
    );
    expect(features, hasLength(1));
  });

  testWidgets('cancelling writes nothing and asks nothing', (tester) async {
    var cancelled = false;
    await pumpDuplicate(tester, onCancel: () => cancelled = true);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(cancelled, isTrue);
    final sites = await tester.runAsync(() => SiteRepository().getAllSites());
    expect(sites!.map((s) => s.id), ['site-1']);
  });

  testWidgets('the copy keeps the original\'s sharing', (tester) async {
    await tester.runAsync(
      () => (db.update(db.diveSites)..where((t) => t.id.equals('site-1')))
          .write(const DiveSitesCompanion(isShared: Value(true))),
    );

    // Already loaded, the form fills before the new-site sharing default
    // arrives, which must not then overwrite the original's sharing.
    final copyId = await saveDuplicate(tester, sourceLoaded: true);

    final copy = (await tester.runAsync(
      () => SiteRepository().getSiteById(copyId),
    ))!;
    expect(copy.isShared, isTrue);
  });

  /// Adds diver profiles, which share rows and owners refer to.
  Future<void> addDivers(WidgetTester tester, List<String> ids) async {
    final now = DateTime(2026, 10, 23).millisecondsSinceEpoch;
    await tester.runAsync(() async {
      for (final id in ids) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }

  testWidgets('my own site\'s copy is shared with the same profiles by name '
      '(issue #2151)', (tester) async {
    await addDivers(tester, ['me', 'buddy']);
    await tester.runAsync(() async {
      await (db.update(db.diveSites)..where((t) => t.id.equals('site-1')))
          .write(const DiveSitesCompanion(diverId: Value('me')));
      await ItemSharesRepository().setSharing(
        SharedItemKind.site,
        'site-1',
        const ItemSharing(profileIds: {'buddy'}),
        actingDiverId: 'me',
      );
    });

    final copyId = await saveDuplicate(tester, diverId: 'me');

    final shared = await tester.runAsync(
      () =>
          ItemSharesRepository().storedProfileIds(SharedItemKind.site, copyId),
    );
    expect(shared, {'buddy'});
  });

  testWidgets('another profile\'s shared site copies as a new site is '
      'shared, not as its owner chose', (tester) async {
    await addDivers(tester, ['me', 'owner', 'buddy']);
    await tester.runAsync(() async {
      await (db.update(
        db.diveSites,
      )..where((t) => t.id.equals('site-1'))).write(
        const DiveSitesCompanion(
          diverId: Value('owner'),
          isShared: Value(true),
        ),
      );
    });

    final copyId = await saveDuplicate(tester, diverId: 'me');

    final copy = (await tester.runAsync(
      () => SiteRepository().getSiteById(copyId),
    ))!;
    expect(copy.isShared, isFalse);
  });

  testWidgets('a shared library site duplicates as a personal site', (
    tester,
  ) async {
    await tester.runAsync(
      () => (db.update(db.diveSites)..where((t) => t.id.equals('site-1')))
          .write(const DiveSitesCompanion(sharedLibraryId: Value('lib-1'))),
    );

    final copyId = await saveDuplicate(tester);

    final copy = (await tester.runAsync(
      () => SiteRepository().getSiteById(copyId),
    ))!;
    expect(copy.sharedLibraryId, isNull);
    expect(copy.name, 'Salt Pier (copy)');
  });

  testWidgets('the page is titled Duplicate Site', (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides()],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: SiteEditPage.fromNewSiteExtra(null, duplicateOfId: 'site-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Duplicate Site'), findsOneWidget);
    expect(find.text('New Site'), findsNothing);
  });

  /// Pushes the duplicate form from an opener page, saves it, and returns
  /// the copy's id. The opener shows what the form popped.
  Future<String> saveFromOpener(
    WidgetTester tester, {
    List<dynamic> extraOverrides = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/opener',
      routes: [
        GoRoute(path: '/opener', builder: (context, state) => const _Opener()),
        GoRoute(
          path: '/sites/new',
          builder: (context, state) => SiteEditPage.fromNewSiteExtra(
            state.extra,
            duplicateOfId: state.uri.queryParameters['duplicateOf'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides(), ...extraOverrides],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DUPLICATE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final sites = await tester.runAsync(() => SiteRepository().getAllSites());
    return sites!.map((s) => s.id).singleWhere((id) => id != 'site-1');
  }

  testWidgets('saving the full-page form returns the copy to its opener', (
    tester,
  ) async {
    final copyId = await saveFromOpener(tester);

    // The opener knows where it is, so it decides where the copy shows.
    expect(find.text('popped $copyId'), findsOneWidget);
    expect(find.text('Site added'), findsOneWidget);
  });

  testWidgets('features that fail to copy still return the saved copy, and '
      'say so', (tester) async {
    final copyId = await saveFromOpener(
      tester,
      extraOverrides: [
        siteFeatureRepositoryProvider.overrideWithValue(
          _FailingCopyRepository(),
        ),
      ],
    );

    // The site saved, so the form closes rather than leaving the diver on a
    // form whose second Save would make another copy.
    expect(find.text('popped $copyId'), findsOneWidget);
    expect(
      find.text('Site added, but its map features could not be copied.'),
      findsOneWidget,
    );
    expect(find.text('Site added'), findsNothing);
  });
}

/// Pushes the duplicate form and shows the id it pops.
class _Opener extends StatefulWidget {
  const _Opener();

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  String? _popped;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final id = await context.push<String>(
              '/sites/new?duplicateOf=site-1',
            );
            setState(() => _popped = id);
          },
          child: const Text('DUPLICATE'),
        ),
        Text('popped $_popped'),
      ],
    ),
  );
}

/// Copies nothing and fails, as a write error part-way would.
class _FailingCopyRepository extends SiteFeatureRepository {
  @override
  Future<void> copyFeatures({
    required String fromSiteId,
    required String toSiteId,
    String? actingDiverId,
  }) async => throw StateError('disk full');
}
