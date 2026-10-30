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

BundledSpeciesCatalog _catalog(int version, List<domain.Species> rows) =>
    BundledSpeciesCatalog(version: version, species: rows);

void main() {
  late AppDatabase db;
  late SpeciesRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = SpeciesRepository();
  });

  tearDown(() async {
    SpeciesSeedService.clearCache();
    await tearDownTestDatabase();
  });

  Future<Specy> read(String id) =>
      (db.select(db.species)..where((t) => t.id.equals(id))).getSingle();

  Future<void> insertOld(String id) => db
      .into(db.species)
      .insert(
        SpeciesCompanion(
          id: Value(id),
          commonName: const Value('Old'),
          category: const Value('fish'),
          isBuiltIn: const Value(true),
        ),
      );

  test('first launch inserts every row and records the version', () async {
    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    final store = InMemorySeedVersionStore();

    await repository.seedBuiltInSpecies(versionStore: store);

    expect((await read('sp_a')).commonName, 'A');
    expect((await read('sp_a')).hlc, isNull);
    expect(store.version, 2);
  });

  test(
    'a newer catalog updates untouched rows and keeps edited ones',
    () async {
      SpeciesSeedService.overrideCatalog(
        _catalog(1, [_row('sp_a', 'A'), _row('sp_b', 'B')]),
      );
      final store = InMemorySeedVersionStore();
      await repository.seedBuiltInSpecies(versionStore: store);
      // The diver renames B: every edit path stamps an hlc.
      await repository.updateSpecies(
        (await repository.getSpeciesById('sp_b'))!.copyWith(commonName: 'Mine'),
      );
      expect((await read('sp_b')).hlc, isNotNull);

      SpeciesSeedService.overrideCatalog(
        _catalog(2, [
          _row('sp_a', 'A2'),
          _row('sp_b', 'B2'),
          _row('sp_c', 'C'),
        ]),
      );
      await repository.seedBuiltInSpecies(versionStore: store);

      expect((await read('sp_a')).commonName, 'A2');
      expect((await read('sp_b')).commonName, 'Mine');
      expect((await read('sp_c')).commonName, 'C');
      expect(store.version, 2);
    },
  );

  test('the same version only fills in missing rows', () async {
    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    final store = InMemorySeedVersionStore(2);
    await insertOld('sp_a');

    await repository.seedBuiltInSpecies(versionStore: store);

    expect((await read('sp_a')).commonName, 'Old');
  });

  test('a deleted built-in row comes back at the next version', () async {
    SpeciesSeedService.overrideCatalog(_catalog(1, [_row('sp_a', 'A')]));
    final store = InMemorySeedVersionStore();
    await repository.seedBuiltInSpecies(versionStore: store);
    await repository.deleteSpecies('sp_a');

    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    await repository.seedBuiltInSpecies(versionStore: store);

    expect((await read('sp_a')).commonName, 'A');
  });

  test('without a store the seed is the plain INSERT OR IGNORE', () async {
    SpeciesSeedService.overrideCatalog(_catalog(2, [_row('sp_a', 'A')]));
    await insertOld('sp_a');

    await repository.seedBuiltInSpecies();

    expect((await read('sp_a')).commonName, 'Old');
  });

  // A reset publishes the restored catalog text of every row the diver had
  // edited, so other devices drop the edit too (issue #3669).
  test(
    'resetBuiltInSpecies publishes the restored text of an edited in-use row',
    () async {
      SpeciesSeedService.overrideCatalog(_catalog(1, [_row('sp_a', 'A')]));
      await repository.seedBuiltInSpecies(
        versionStore: InMemorySeedVersionStore(),
      );
      await repository.updateSpecies(
        (await repository.getSpeciesById('sp_a'))!.copyWith(commonName: 'Mine'),
      );
      // In use, so the reset restores rather than deletes it.
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
      await repository.addSighting(diveId: 'd1', speciesId: 'sp_a');

      await repository.resetBuiltInSpecies();

      final row = await read('sp_a');
      expect(row.commonName, 'A');
      expect(row.description, 'A description');
      expect(row.hlc, isNotNull, reason: 'the restored row must export');
      final pending = await db
          .customSelect(
            "SELECT record_id FROM sync_records "
            "WHERE entity_type = 'species' AND record_id = 'sp_a' "
            "AND sync_status = 'pending'",
          )
          .get();
      expect(pending, hasLength(1));
    },
  );

  test(
    'resetBuiltInSpecies publishes an unused edited row and no untouched one',
    () async {
      SpeciesSeedService.overrideCatalog(
        _catalog(1, [_row('sp_a', 'A'), _row('sp_b', 'B')]),
      );
      await repository.seedBuiltInSpecies(
        versionStore: InMemorySeedVersionStore(),
      );
      await repository.updateSpecies(
        (await repository.getSpeciesById('sp_b'))!.copyWith(commonName: 'Mine'),
      );

      await repository.resetBuiltInSpecies();

      expect((await read('sp_b')).commonName, 'B');
      expect((await read('sp_b')).hlc, isNotNull);
      expect((await read('sp_a')).hlc, isNull);
      final pending = await db
          .customSelect(
            "SELECT record_id FROM sync_records "
            "WHERE entity_type = 'species'",
          )
          .get();
      expect(pending.map((r) => r.data['record_id']), ['sp_b']);
    },
  );

  // A built-in species tagged on a photo or listed as expected at a site is
  // diver data too. The reset used to delete every built-in row without a
  // sighting, and ON DELETE CASCADE took those rows with it.
  test(
    'resetBuiltInSpecies keeps photo tags and expected-species entries',
    () async {
      SpeciesSeedService.overrideCatalog(
        _catalog(1, [_row('sp_a', 'A'), _row('sp_b', 'B')]),
      );
      await repository.seedBuiltInSpecies(
        versionStore: InMemorySeedVersionStore(),
      );
      await insertTestSite('s1', 'Reef');
      await insertTestMedia(id: 'm1', siteId: 's1');
      await MediaSpeciesRepository().addTag(mediaId: 'm1', speciesId: 'sp_a');
      await repository.addExpectedSpecies(siteId: 's1', speciesId: 'sp_b');

      await repository.resetBuiltInSpecies();

      final tags = await db.select(db.mediaSpecies).get();
      expect(tags.map((t) => t.speciesId), ['sp_a']);
      final expected = await db.select(db.siteSpecies).get();
      expect(expected.map((e) => e.speciesId), ['sp_b']);
    },
  );
}
