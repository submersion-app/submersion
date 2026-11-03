import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<void> species(String id, String name) => db
      .into(db.species)
      .insert(
        SpeciesCompanion.insert(id: id, commonName: name, category: 'fish'),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await species('sp1', 'Clownfish');
    await species('sp2', 'Moray eel');
    await db
        .into(db.sightings)
        .insert(
          const SightingsCompanion(
            id: Value('s1'),
            diveId: Value('d1'),
            speciesId: Value('sp1'),
            count: Value(2),
            notes: Value('Anemone'),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a sighting is added with its species and count', () async {
    final result = await h.run([
      createOp('sightings', {'dive_id': 'd2', 'species_id': 'sp2', 'count': 3}),
    ]);

    final doc = (await h.one(
      'sightings',
      result.created.single.id,
      diverId: kDiverB,
    ))!;
    expect(doc['dive_id'], 'd2');
    expect(doc['species_name'], 'Moray eel');
    expect(doc['count'], 3);
    expect(doc['notes'], '');
    expect(h.refreshed.single, {'d2'});
  });

  test('a new sighting names its species and its dive', () async {
    final plan = await h.preview([
      createOp('sightings', {'dive_id': 'd1', 'species_id': 'sp2'}),
    ]);

    expect(plan.items.single.names, {'d1': 'Dive d1', 'sp2': 'Moray eel'});
  });

  test('a species that does not exist is blocked', () async {
    final plan = await h.preview([
      createOp('sightings', {'dive_id': 'd1', 'species_id': 'nope'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.unknownReference);
  });

  test('a species gone after the preview refuses the plan', () async {
    final plan = await h.preview([
      createOp('sightings', {'dive_id': 'd1', 'species_id': 'sp2'}),
    ]);
    await (db.delete(db.species)..where((s) => s.id.equals('sp2'))).go();

    await expectLater(
      h.apply(plan),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.planStale,
        ),
      ),
    );
  });

  test('an update keeps what it does not name', () async {
    await h.run([
      updateOp('sightings', 's1', {'count': 5}),
    ]);

    final doc = (await h.one('sightings', 's1'))!;
    expect(doc['count'], 5);
    expect(doc['notes'], 'Anemone');
    expect(doc['species_id'], 'sp1');
  });

  test('a sighting keeps its species', () async {
    final plan = await h.preview([
      updateOp('sightings', 's1', {'species_id': 'sp2'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
    expect(plan.items.single.title, 'Clownfish');
  });

  test('a delete removes the sighting and a revert restores it', () async {
    final result = await h.run([deleteOp('sightings', 's1')]);
    expect(await h.one('sightings', 's1'), isNull);

    await h.revert(result);

    expect((await h.one('sightings', 's1'))!['count'], 2);
  });
}
