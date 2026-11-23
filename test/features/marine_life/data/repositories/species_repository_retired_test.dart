import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_seed_service.dart';
import 'package:submersion/features/marine_life/domain/entities/bundled_species_catalog.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/in_memory_seed_version_store.dart';
import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

domain.Species _row(String id, String name) => domain.Species(
  id: id,
  commonName: name,
  scientificName: '$name sci',
  category: SpeciesCategory.fish,
  description: '$name description',
  isBuiltIn: true,
);

/// Version 1 ships a twin of sp_manta; version 2 drops it and retires its id
/// onto sp_manta (issue #4966).
final _v1 = BundledSpeciesCatalog(
  version: 1,
  species: [_row('sp_manta', 'Manta'), _row('sp_twin', 'Manta twin')],
);
final _v2 = BundledSpeciesCatalog(
  version: 2,
  species: [_row('sp_manta', 'Manta')],
  retired: const {'sp_twin': 'sp_manta'},
);

void main() {
  late AppDatabase db;
  late SpeciesRepository repository;
  late InMemorySeedVersionStore store;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = SpeciesRepository();
    store = InMemorySeedVersionStore();
    SpeciesSeedService.overrideCatalog(_v1);
    await repository.seedBuiltInSpecies(versionStore: store);
    await insertTestSite('s1', 'Reef');
    await insertTestMedia(id: 'm1', siteId: 's1');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async {
    SpeciesSeedService.clearCache();
    await tearDownTestDatabase();
  });

  Future<Specy?> read(String id) =>
      (db.select(db.species)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<String>> records(String entityType, String status) async {
    final rows = await db
        .customSelect(
          'SELECT record_id FROM sync_records '
          'WHERE entity_type = ? AND sync_status = ?',
          variables: [
            Variable.withString(entityType),
            Variable.withString(status),
          ],
        )
        .get();
    return rows.map((r) => r.data['record_id'] as String).toList();
  }

  Future<List<String>> deletions(String entityType) async {
    final rows = await db
        .customSelect(
          'SELECT record_id FROM deletion_log WHERE entity_type = ?',
          variables: [Variable.withString(entityType)],
        )
        .get();
    return rows.map((r) => r.data['record_id'] as String).toList();
  }

  Future<void> upgrade() async {
    SpeciesSeedService.overrideCatalog(_v2);
    await repository.seedBuiltInSpecies(versionStore: store);
  }

  test('the upgrade moves sightings onto the kept species', () async {
    final sighting = await repository.addSighting(
      diveId: 'd1',
      speciesId: 'sp_twin',
    );
    await db.delete(db.syncRecords).go();

    await upgrade();

    expect(await read('sp_twin'), isNull);
    final rows = await db.select(db.sightings).get();
    expect(rows.map((r) => r.speciesId), ['sp_manta']);
    expect(rows.single.hlc, isNotNull);
    expect(await records('sightings', 'pending'), [sighting.id]);
    expect(store.version, 2);
  });

  test('a dive logged with both keeps both sightings', () async {
    await repository.addSighting(diveId: 'd1', speciesId: 'sp_manta');
    await repository.addSighting(diveId: 'd1', speciesId: 'sp_twin');

    await upgrade();

    final rows = await db.select(db.sightings).get();
    expect(rows.map((r) => r.speciesId), ['sp_manta', 'sp_manta']);
  });

  test('a photo tag moves, or goes when the photo has both', () async {
    await insertTestMedia(id: 'm2', siteId: 's1');
    final tags = MediaSpeciesRepository();
    final moved = await tags.addTag(mediaId: 'm1', speciesId: 'sp_twin');
    await tags.addTag(mediaId: 'm2', speciesId: 'sp_manta');
    final dropped = await tags.addTag(mediaId: 'm2', speciesId: 'sp_twin');
    await db.delete(db.syncRecords).go();

    await upgrade();

    final rows = await (db.select(
      db.mediaSpecies,
    )..orderBy([(t) => OrderingTerm.asc(t.mediaId)])).get();
    expect(rows.map((r) => (r.mediaId, r.speciesId)), [
      ('m1', 'sp_manta'),
      ('m2', 'sp_manta'),
    ]);
    expect(rows.first.id, moved.id);
    expect(await records('mediaSpecies', 'pending'), [moved.id]);
    expect(await deletions('mediaSpecies'), [dropped.id]);
  });

  test(
    'a dropped twin tag the diver confirmed confirms the kept tag',
    () async {
      final tags = MediaSpeciesRepository();
      final kept = await tags.addTag(
        mediaId: 'm1',
        speciesId: 'sp_manta',
        unconfirmed: true,
      );
      await tags.addTag(mediaId: 'm1', speciesId: 'sp_twin');
      await db.delete(db.syncRecords).go();

      await upgrade();

      final row = await db.select(db.mediaSpecies).getSingle();
      expect(row.id, kept.id);
      expect(row.unconfirmed, isNull);
      expect(await records('mediaSpecies', 'pending'), [kept.id]);
    },
  );

  test('a dropped twin entry passes its notes to a kept one without', () async {
    await repository.addExpectedSpecies(siteId: 's1', speciesId: 'sp_manta');
    await repository.addExpectedSpecies(
      siteId: 's1',
      speciesId: 'sp_twin',
      notes: 'At the cleaning station',
    );
    final kept = (await db.select(db.siteSpecies).get())
        .firstWhere((r) => r.speciesId == 'sp_manta')
        .id;
    await db.delete(db.syncRecords).go();

    await upgrade();

    final row = await db.select(db.siteSpecies).getSingle();
    expect(row.id, kept);
    expect(row.notes, 'At the cleaning station');
    expect(await records('siteSpecies', 'pending'), [kept]);
  });

  test('an expected species moves, or goes when the site has both', () async {
    await insertTestSite('s2', 'Wall');
    await repository.addExpectedSpecies(siteId: 's1', speciesId: 'sp_twin');
    await repository.addExpectedSpecies(siteId: 's2', speciesId: 'sp_manta');
    await repository.addExpectedSpecies(siteId: 's2', speciesId: 'sp_twin');
    final before = await db.select(db.siteSpecies).get();
    final moved = before.firstWhere((r) => r.siteId == 's1').id;
    final dropped = before
        .firstWhere((r) => r.siteId == 's2' && r.speciesId == 'sp_twin')
        .id;
    await db.delete(db.syncRecords).go();

    await upgrade();

    final rows = await (db.select(
      db.siteSpecies,
    )..orderBy([(t) => OrderingTerm.asc(t.siteId)])).get();
    expect(rows.map((r) => (r.siteId, r.speciesId)), [
      ('s1', 'sp_manta'),
      ('s2', 'sp_manta'),
    ]);
    expect(await records('siteSpecies', 'pending'), [moved]);
    expect(await deletions('siteSpecies'), [dropped]);
  });

  test('an identification naming the twin names the kept species', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.mediaIdentifications)
        .insert(
          MediaIdentificationsCompanion.insert(
            id: 'i1',
            mediaId: 'm1',
            boxX: 0,
            boxY: 0,
            boxWidth: 1,
            boxHeight: 1,
            boxPixelWidth: 10,
            boxPixelHeight: 10,
            detectorScore: 0.9,
            openScore: 0.9,
            candidatesJson: '[]',
            locationLimited: false,
            suggestable: true,
            decision: 'accepted',
            decidedSpeciesId: const Value('sp_twin'),
            claimedSpeciesId: const Value('sp_twin'),
            createdAt: now,
          ),
        );

    await upgrade();

    final row = await db.select(db.mediaIdentifications).getSingle();
    expect(row.decidedSpeciesId, 'sp_manta');
    expect(row.claimedSpeciesId, 'sp_manta');
    expect(await records('mediaIdentifications', 'pending'), ['i1']);
  });

  test('a twin the diver edited stays, with its sightings', () async {
    await repository.updateSpecies(
      (await repository.getSpeciesById(
        'sp_twin',
      ))!.copyWith(commonName: 'Mine'),
    );
    await repository.addSighting(diveId: 'd1', speciesId: 'sp_twin');

    await upgrade();

    expect((await read('sp_twin'))!.commonName, 'Mine');
    final rows = await db.select(db.sightings).get();
    expect(rows.map((r) => r.speciesId), ['sp_twin']);
  });

  test('a failed fold leaves the launch going and retries next time', () async {
    await repository.addSighting(diveId: 'd1', speciesId: 'sp_twin');
    // Any SQL failure inside the fold: here a table it writes is missing.
    await db.customStatement('DROP TABLE media_identifications');

    await upgrade();

    expect(await read('sp_twin'), isNotNull);
    final rows = await db.select(db.sightings).get();
    expect(rows.map((r) => r.speciesId), ['sp_twin']);
    expect(store.version, 1, reason: 'the next launch must try again');
  });

  test('the same version leaves a twin alone', () async {
    store = InMemorySeedVersionStore(2);
    await repository.addSighting(diveId: 'd1', speciesId: 'sp_twin');

    await upgrade();

    expect(await read('sp_twin'), isNotNull);
  });

  test('a reset folds even an edited twin into the kept species', () async {
    await upgrade();
    // A peer's edited copy of the twin came back through sync.
    await db
        .into(db.species)
        .insert(
          const SpeciesCompanion(
            id: Value('sp_twin'),
            commonName: Value('Mine'),
            category: Value('fish'),
            isBuiltIn: Value(true),
            hlc: Value('peer-hlc'),
          ),
        );
    await repository.addSighting(diveId: 'd1', speciesId: 'sp_twin');

    await repository.resetBuiltInSpecies();

    expect(await read('sp_twin'), isNull);
    final rows = await db.select(db.sightings).get();
    expect(rows.map((r) => r.speciesId), ['sp_manta']);
  });
}
