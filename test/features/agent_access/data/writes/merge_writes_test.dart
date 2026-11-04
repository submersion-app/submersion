import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Merging duplicate sites, buddies and dive computers, as their pages
/// merge them: the merged record goes and its links move to the survivor.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(
    String entity,
    Map<String, Object?> values, {
    String? diver,
  }) async =>
      (await h.run([createOp(entity, values, diver: diver)])).created.single.id;

  Map<String, Object?> onDive(String dive, String relation, String id) => {
    ...updateOp('dives', dive, {}),
    'relations': {
      relation: relation == 'site'
          ? {
              'set': [id],
            }
          : {
              'add': [id],
            },
    },
  };

  Future<void> computer(String id) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'gear-$id',
            name: 'Computer $id',
            type: 'computer',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: 'Computer $id',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
            equipmentId: Value('gear-$id'),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('two sites merge into one with every link listed', () async {
    final keep = await make('sites', {'name': 'Blue Hole'});
    final dupe = await make('sites', {'name': 'The Blue Hole'});
    await h.run([onDive('d1', 'site', dupe)]);

    final plan = await h.preview([deleteOp('sites', dupe, mergeInto: keep)]);
    expect(plan.items.single.reach.moved['dives'], 1);
    await h.apply(plan);

    expect(await h.one('sites', dupe), isNull);
    final dive = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('d1'))).getSingle();
    expect(dive.siteId, keep);
  });

  test('a site of another profile can only survive a merge', () async {
    final mine = await make('sites', {'name': 'Mine'});
    final private = await make('sites', {'name': 'Theirs'}, diver: kDiverB);
    final shared = await make('sites', {'name': 'Shared'}, diver: kDiverB);
    await h.run([
      {
        ...updateOp('sites', shared, {}),
        'relations': {
          'shared_with': {
            'add': [kDiverA],
          },
        },
      },
    ]);

    final plan = await h.preview([deleteOp('sites', mine, mergeInto: private)]);
    expect(plan.items.single.block!.reason, BlockReason.otherProfileReference);

    final into = await h.preview([deleteOp('sites', mine, mergeInto: shared)]);
    expect(into.items.single.block, isNull);
  });

  test('two buddies merge', () async {
    final keep = await make('buddies', {'name': 'Rui'});
    final dupe = await make('buddies', {'name': 'Rui S.'});
    await h.run([onDive('d1', 'buddies', dupe)]);

    final plan = await h.preview([deleteOp('buddies', dupe, mergeInto: keep)]);
    expect(plan.items.single.reach.moved['dive_buddies'], 1);
    await h.apply(plan);

    expect(await h.one('buddies', dupe), isNull);
    final links = await db.select(db.diveBuddies).get();
    expect([for (final l in links) l.buddyId], [keep]);
  });

  test('two computers merge with their dives listed', () async {
    await computer('c1');
    await computer('c2');
    await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
      const DivesCompanion(computerId: Value('c2')),
    );

    final plan = await h.preview([
      deleteOp('dive_computers', 'c2', mergeInto: 'c1'),
    ]);
    expect(plan.items.single.reach.moved['dives'], 1);
    await h.apply(plan);

    expect(await h.one('dive_computers', 'c2'), isNull);
    final dive = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('d1'))).getSingle();
    expect(dive.computerId, 'c1');
  });

  // mergeComputers rewrites the survivor from both records and folds the
  // duplicate's gear item into the survivor's.
  test('a computer merge lists what it changes on the survivor and the gear '
      'item it folds away', () async {
    await computer('c1');
    await computer('c2');
    await (db.update(db.diveComputers)..where((c) => c.id.equals('c2'))).write(
      const DiveComputersCompanion(
        serialNumber: Value('SN2'),
        diveCount: Value(3),
      ),
    );

    final plan = await h.preview([
      deleteOp('dive_computers', 'c2', mergeInto: 'c1'),
    ]);
    final reach = plan.items.single.reach;
    expect(reach.survivor, {'serial_number': 'SN2', 'dive_count': 3});
    expect(reach.records, {'equipment': 1});
    await h.apply(plan);

    expect((await h.one('dive_computers', 'c1'))!['serial_number'], 'SN2');
    expect(await h.one('equipment', 'gear-c2'), isNull);
  });

  test('a computer merge reverts through the change log', () async {
    await computer('c1');
    await computer('c2');
    await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
      const DivesCompanion(computerId: Value('c2')),
    );

    final result = await h.run([
      deleteOp('dive_computers', 'c2', mergeInto: 'c1'),
    ]);
    await h.revert(result);

    expect((await h.one('dive_computers', 'c2'))!['name'], 'Computer c2');
    expect((await h.one('equipment', 'gear-c2'))!['name'], 'Computer c2');
    final dive = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('d1'))).getSingle();
    expect(dive.computerId, 'c2');
  });

  test('a site merge reverts through the change log', () async {
    final keep = await make('sites', {'name': 'Blue Hole'});
    final dupe = await make('sites', {'name': 'The Blue Hole'});
    await h.run([onDive('d1', 'site', dupe)]);

    final result = await h.run([deleteOp('sites', dupe, mergeInto: keep)]);
    await h.revert(result);

    expect((await h.one('sites', dupe))!['name'], 'The Blue Hole');
    final dive = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('d1'))).getSingle();
    expect(dive.siteId, dupe);
  });

  test('a merge reverts through the change log', () async {
    final keep = await make('buddies', {'name': 'Rui'});
    final dupe = await make('buddies', {'name': 'Rui S.'});

    final result = await h.run([deleteOp('buddies', dupe, mergeInto: keep)]);
    await h.revert(result);

    expect((await h.one('buddies', dupe))!['name'], 'Rui S.');
  });

  // The counts stay the same when a link moves between dives, or the
  // survivor gains one, but the merge then moves or collapses other rows
  // than the preview described.
  test('a link that moves after the preview refuses the merge', () async {
    final stale = isA<AgentToolException>().having(
      (e) => e.code,
      'code',
      AgentToolErrorCode.planStale,
    );
    await h.dive('d3');
    final keep = await make('buddies', {'name': 'Rui'});
    final dupe = await make('buddies', {'name': 'Rui S.'});
    await h.run([onDive('d1', 'buddies', dupe)]);

    final moved = await h.preview([deleteOp('buddies', dupe, mergeInto: keep)]);
    await (db.update(db.diveBuddies)..where((l) => l.buddyId.equals(dupe)))
        .write(const DiveBuddiesCompanion(diveId: Value('d3')));
    await expectLater(h.apply(moved), throwsA(stale));

    final gained = await h.preview([
      deleteOp('buddies', dupe, mergeInto: keep),
    ]);
    await h.run([onDive('d1', 'buddies', keep)]);
    await expectLater(h.apply(gained), throwsA(stale));
  });
}
