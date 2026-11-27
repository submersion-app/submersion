import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_new_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_save.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

const _source = DiveSite(
  id: 'site-1',
  diverId: 'me',
  name: 'Salt Pier',
  description: 'Pier pilings',
  location: GeoPoint(12.08, -68.28),
  maxDepth: 18,
  rating: 4,
  notes: 'Ask the pier office first',
  hazards: 'Boat traffic',
);

/// A new site's sitting (issue #4527, phase 2, plan 6): the seed holds only
/// the defaults, and what a seed request or a duplicate brings is put on it
/// as changes, through the cards' own functions.
void main() {
  late ProviderContainer container;
  var shareByDefault = false;

  setUp(() async {
    final db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDiver(db, 'other');
    shareByDefault = false;
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((_) async => 'me'),
        shareByDefaultProvider.overrideWith((_) async => shareByDefault),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  /// A sitting on a fresh seed, started as the page starts one.
  Future<EditSession<DiveSite>> newSitting() async {
    final seed = await newSiteSeed(container.read, id: 'n1');
    final session = EditSession<DiveSite>(seed, isNew: true);
    addTearDown(session.dispose);
    startSiteSitting(session, container.read);
    return session;
  }

  Future<PlaceLookup> place(GeoPoint _) async =>
      const PlaceLookup(country: 'Egypt', region: 'Red Sea');

  test('a seed is the active diver\'s, shared by default, with nothing '
      'else', () async {
    shareByDefault = true;
    final seed = await newSiteSeed(container.read, id: 'n1');

    expect(seed.id, 'n1');
    expect(seed.diverId, 'me');
    expect(seed.isShared, isTrue);
    expect(seed.name, '');
    expect(seed.location, isNull);
    expect(EditSession<DiveSite>(seed, isNew: true).isDirty, isFalse);
  });

  test('a seed\'s name is a change of the header block', () async {
    final session = await newSitting();

    await applyNewSitePrefill(
      session,
      seed: const NewSiteSeed(name: 'Blue Hole'),
      lookUpPlace: place,
      fetchElevation: (_) async => null,
    );

    expect(session.valueOf(siteNameField), 'Blue Hole');
    expect(session.isDirty, isTrue);
    expect(session.changedCardIds, {siteHeaderCardId});
  });

  test('a seed\'s point fills empty place names and the altitude, as '
      'changes', () async {
    for (final (metres, altitude) in [(120.0, true), (-5.0, false)]) {
      final session = await newSitting();

      await applyNewSitePrefill(
        session,
        seed: const NewSiteSeed(location: GeoPoint(12, 34)),
        lookUpPlace: place,
        fetchElevation: (_) async => metres,
        altitudeDelay: Duration.zero,
      );
      await session.settled();

      expect(session.valueOf(siteLocationField), const GeoPoint(12, 34));
      expect(session.valueOf(siteCountryField), 'Egypt');
      expect(session.valueOf(siteRegionField), 'Red Sea');
      expect(session.changedCardIds, contains('location'));
      expect(session.changedCardIds.contains('altitude'), altitude);
    }
  });

  // Review Focus 1.
  test(
    'a typed country survives a late lookup, and Save waits for it',
    () async {
      final session = await newSitting();
      final answer = Completer<PlaceLookup>();

      unawaited(
        applyNewSitePrefill(
          session,
          seed: const NewSiteSeed(location: GeoPoint(12, 34)),
          lookUpPlace: (_) => answer.future,
          fetchElevation: (_) async => null,
          altitudeDelay: Duration.zero,
        ),
      );
      await pumpEventQueue();
      session.set(siteCountryField, 'Sinai');
      expect(session.isSettled, isFalse);
      answer.complete(const PlaceLookup(country: 'Egypt', region: 'Red Sea'));
      await session.settled();

      expect(session.valueOf(siteCountryField), 'Sinai');
      expect(session.valueOf(siteRegionField), 'Red Sea');
    },
  );

  test('a lookup that fails fills nothing', () async {
    final session = await newSitting();

    await applyNewSitePrefill(
      session,
      seed: const NewSiteSeed(location: GeoPoint(12, 34)),
      lookUpPlace: (_) async => throw StateError('offline'),
      fetchElevation: (_) async => null,
      altitudeDelay: Duration.zero,
    );
    await session.settled();

    expect(session.valueOf(siteLocationField), const GeoPoint(12, 34));
    expect(session.valueOf(siteCountryField), isNull);
  });

  group('a duplicate', () {
    setUp(() async {
      final now = DateTime(2026, 11, 19);
      final tags = TagRepository();
      for (final (id, owner) in [('tag-1', null), ('tag-other', 'other')]) {
        await tags.createTag(
          Tag(
            id: id,
            diverId: owner,
            name: id,
            createdAt: now,
            updatedAt: now,
            scopes: const {TagScope.sites},
          ),
        );
      }
      await SiteRepository().createSite(
        _source,
        classification: const SiteClassification(
          typeIds: ['wall'],
          tagIds: ['tag-1', 'tag-other'],
        ),
      );
      final species = SpeciesRepository();
      final seahorse = await species.createSpecies(
        commonName: 'Seahorse',
        category: SpeciesCategory.fish,
      );
      await species.addExpectedSpecies(
        siteId: 'site-1',
        speciesId: seahorse.id,
      );
      await SiteFeatureRepository().addFeature(
        siteId: 'site-1',
        typeName: 'mooring',
        name: 'North ball',
        latitude: 12.0819,
        longitude: -68.2806,
      );
    });

    // Review Focus 2.
    test('its lists are set once the loads settle, and Save waits for '
        'them', () async {
      final source = (await readSiteDuplicate(container.read, 'site-1'))!;
      final session = await newSitting();

      final prefill = applyNewSitePrefill(
        session,
        duplicate: source,
        duplicateName: 'Copy of Salt Pier',
        lookUpPlace: place,
        fetchElevation: (_) async => null,
      );
      expect(session.isSettled, isFalse);
      await prefill;
      await session.settled();

      expect(session.valueOf(siteNameField), 'Copy of Salt Pier');
      expect(session.valueOf(siteHazardsField), 'Boat traffic');
      expect([for (final t in siteTypesList.current(session)!) t.id], ['wall']);
      // Only the diver's own tags travel.
      expect([for (final t in siteTagsList.current(session)!) t.id], ['tag-1']);
      expect(siteSpeciesList.current(session), hasLength(1));
      expect(siteFeaturesList.current(session)!.single.name, 'North ball');
      expect(
        session.changedCardIds,
        containsAll([
          siteHeaderCardId,
          'tags',
          'marineLife',
          'features',
          'hazards',
          'depth',
        ]),
      );
    });

    // Review Focus 4.
    test('of another profile\'s or a library site is shared as a new site '
        'is', () async {
      final repository = SiteRepository();
      await repository.createSite(
        _source.copyWith(id: 'theirs', diverId: 'other'),
      );
      await repository.createSite(
        _source.copyWith(id: 'library', sharedLibraryId: 'L'),
      );
      for (final id in ['theirs', 'library']) {
        for (final byDefault in [true, false]) {
          shareByDefault = byDefault;
          container.invalidate(shareByDefaultProvider);
          final source = (await readSiteDuplicate(container.read, id))!;
          expect(
            source.sharing,
            byDefault ? ItemSharing.all : ItemSharing.none,
            reason: '$id, share by default $byDefault',
          );
        }
      }

      final source = (await readSiteDuplicate(container.read, 'library'))!;
      final session = await newSitting();
      await applyNewSitePrefill(
        session,
        duplicate: source,
        duplicateName: 'Copy',
        lookUpPlace: place,
        fetchElevation: (_) async => null,
      );
      await session.settled();

      expect(session.working.sharedLibraryId, isNull);
      expect(session.working.diverId, 'me');
      expect(session.valueOf(siteNotesField), 'Ask the pier office first');
      expect(session.valueOf(siteRatingField), 4);
    });

    test('of the diver\'s own site keeps its sharing with named '
        'profiles', () async {
      await ItemSharesRepository().setSharing(
        SharedItemKind.site,
        'site-1',
        const ItemSharing(profileIds: {'other'}),
        actingDiverId: 'me',
      );

      final source = (await readSiteDuplicate(container.read, 'site-1'))!;

      expect(source.sharing, const ItemSharing(profileIds: {'other'}));
      final session = await newSitting();
      await applyNewSitePrefill(
        session,
        duplicate: source,
        duplicateName: 'Copy',
        lookUpPlace: place,
        fetchElevation: (_) async => null,
      );
      await session.settled();
      expect(siteSharing.inSitting(session), source.sharing);
    });

    // Review Focus 2 and 4 end to end: the copy's rows reach the database
    // with the site, and its features keep the original's order.
    test('is created with every copied row, features in order', () async {
      final features = SiteFeatureRepository();
      for (final name in ['A', 'B', 'C', 'D', 'E']) {
        // A millisecond apart, so the original's own order is certain.
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await features.addFeature(
          siteId: 'site-1',
          typeName: 'mooring',
          name: name,
          latitude: 1,
          longitude: 2,
        );
      }
      await ItemSharesRepository().setSharing(
        SharedItemKind.site,
        'site-1',
        const ItemSharing(profileIds: {'other'}),
        actingDiverId: 'me',
      );
      final source = (await readSiteDuplicate(container.read, 'site-1'))!;
      final session = await newSitting();
      await applyNewSitePrefill(
        session,
        duplicate: source,
        duplicateName: 'Copy of Salt Pier',
        lookUpPlace: place,
        fetchElevation: (_) async => null,
      );
      await session.settled();

      await createSiteSitting(session, SiteEditSaveService(SiteRepository()));

      final copy = (await SiteRepository().getSiteById('n1'))!;
      expect(copy.name, 'Copy of Salt Pier');
      expect(copy.hazards, 'Boat traffic');
      final classification = SiteClassificationRepository();
      expect(
        [for (final t in await classification.getTypesForSite('n1')) t.id],
        ['wall'],
      );
      expect(
        [for (final t in await classification.getTagsForSite('n1')) t.id],
        ['tag-1'],
      );
      expect(
        await SpeciesRepository().getExpectedSpeciesForSite('n1'),
        hasLength(1),
      );
      expect(
        [for (final f in await features.getFeaturesForSite('n1')) f.name],
        ['North ball', 'A', 'B', 'C', 'D', 'E'],
      );
      expect(
        await ItemSharesRepository().storedProfileIds(
          SharedItemKind.site,
          'n1',
        ),
        {'other'},
      );
    });

    /// A duplicate of [id], prefilled on a new sitting and created.
    Future<EditSession<DiveSite>> createCopyOf(String id) async {
      final source = (await readSiteDuplicate(container.read, id))!;
      final session = await newSitting();
      await applyNewSitePrefill(
        session,
        duplicate: source,
        duplicateName: 'Copy',
        lookUpPlace: place,
        fetchElevation: (_) async => null,
      );
      await session.settled();
      await createSiteSitting(session, SiteEditSaveService(SiteRepository()));
      return session;
    }

    // The form's cases (plan 7).
    test('of another profile\'s site copies only my own types', () async {
      final now = DateTime(2026, 11, 19);
      final types = SiteTypeRepository();
      // The repository suffixes each id, so keep the ones it returns.
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
      final theirType = await custom('Their reef', 'other');
      final myType = await custom('My reef', 'me');
      await SiteRepository().createSite(
        _source.copyWith(id: 'theirs', diverId: 'other'),
        classification: SiteClassification(
          typeIds: ['wall', theirType, myType],
        ),
      );

      final source = (await readSiteDuplicate(container.read, 'theirs'))!;
      expect({for (final t in source.types) t.id}, {'wall', myType});

      await createCopyOf('theirs');
      expect(
        {
          for (final t in await SiteClassificationRepository().getTypesForSite(
            'n1',
          ))
            t.id,
        },
        {'wall', myType},
      );
    });

    test('leaves the original as it was', () async {
      await createCopyOf('site-1');

      final original = (await SiteRepository().getSiteById('site-1'))!;
      expect(original.name, 'Salt Pier');
      expect(original.hazards, 'Boat traffic');
      final classification = SiteClassificationRepository();
      expect(
        [for (final t in await classification.getTypesForSite('site-1')) t.id],
        ['wall'],
      );
      expect(
        {for (final t in await classification.getTagsForSite('site-1')) t.id},
        {'tag-1', 'tag-other'},
      );
      expect(
        await SpeciesRepository().getExpectedSpeciesForSite('site-1'),
        hasLength(1),
      );
      expect(
        [
          for (final f in await SiteFeatureRepository().getFeaturesForSite(
            'site-1',
          ))
            f.name,
        ],
        ['North ball'],
      );
    });

    test('of my site shared with everyone is shared with everyone', () async {
      await SiteRepository().updateSite(
        _source.copyWith(isShared: true),
        actingDiverId: 'me',
      );
      final source = (await readSiteDuplicate(container.read, 'site-1'))!;
      expect(source.sharing.everyone, isTrue);

      await createCopyOf('site-1');
      expect((await SiteRepository().getSiteById('n1'))!.isShared, isTrue);
    });

    test('of a site that is gone reads null', () async {
      expect(await readSiteDuplicate(container.read, 'gone'), isNull);
    });

    test('lays out the starter cards and every card it fills', () async {
      final seed = await newSiteSeed(container.read, id: 'n1');
      final source = (await readSiteDuplicate(container.read, 'site-1'))!;

      expect(
        newSiteLaidOutCards(base: seed, duplicate: source),
        containsAll(['hazards', 'features', 'tags', 'marineLife', 'rating']),
      );
    });
  });

  test('the starter cards, and Altitude for a point', () async {
    final seed = await newSiteSeed(container.read, id: 'n1');

    expect(newSiteLaidOutCards(base: seed), [
      siteHeaderCardId,
      'location',
      'depth',
      'notes',
    ]);
    expect(
      newSiteLaidOutCards(
        base: seed,
        seed: const NewSiteSeed(location: GeoPoint(1, 2)),
      ),
      [siteHeaderCardId, 'location', 'depth', 'notes', 'altitude'],
    );
  });
}
