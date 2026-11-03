import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Species, as the species pages keep them: every species can be edited,
/// built-in ones too, but only a custom species nothing refers to can be
/// deleted, and it leaves the sites that expected it.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> species(String id, String name, {bool builtIn = false}) => db
      .into(db.species)
      .insert(
        SpeciesCompanion.insert(
          id: id,
          commonName: name,
          category: 'fish',
          isBuiltIn: Value(builtIn),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a built-in species can be edited', () async {
    await species('grouper', 'Grouper', builtIn: true);

    await h.run([
      updateOp('species', 'grouper', {'description': 'Large and curious'}),
    ]);

    final doc = (await h.one('species', 'grouper'))!;
    expect(doc['description'], 'Large and curious');
    expect(doc['is_built_in'], isTrue);
  });

  test('a custom species is created and its fields can be cleared', () async {
    final id = (await h.run([
      createOp('species', {
        'common_name': 'Leafy seadragon',
        'scientific_name': 'Phycodurus eques',
        'category': 'fish',
        'taxonomy_class': 'Actinopterygii',
        'description': 'Looks like kelp',
      }),
    ])).created.single.id;

    await h.run([
      updateOp('species', id, {'scientific_name': null, 'category': 'other'}),
    ]);

    final doc = (await h.one('species', id))!;
    expect(doc['common_name'], 'Leafy seadragon');
    expect(doc['scientific_name'], isNull);
    expect(doc['category'], 'other');
    expect(doc['taxonomy_class'], 'Actinopterygii');
    expect(doc['is_built_in'], isFalse);
  });

  test('a built-in species or one with sightings cannot be deleted', () async {
    await species('grouper', 'Grouper', builtIn: true);
    await species('nudi', 'Nudibranch');
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(id: 'sg', diveId: 'd1', speciesId: 'nudi'),
        );

    final plan = await h.preview([
      deleteOp('species', 'grouper'),
      deleteOp('species', 'nudi'),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.notPermitted);
    }
  });

  test(
    'deleting a custom species takes it off the sites expecting it',
    () async {
      await species('nudi', 'Nudibranch');
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 's1',
              name: 'Blue Hole',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverA),
            ),
          );
      await db
          .into(db.siteSpecies)
          .insert(
            SiteSpeciesCompanion.insert(
              id: 'ss',
              siteId: 's1',
              speciesId: 'nudi',
              createdAt: t,
            ),
          );

      final plan = await h.preview([deleteOp('species', 'nudi')]);
      expect(plan.items.single.reach.unlinked, {'site_species': 1});

      await h.apply(plan);
      expect(await h.one('species', 'nudi'), isNull);
      expect(await db.select(db.siteSpecies).get(), isEmpty);
    },
  );
}
