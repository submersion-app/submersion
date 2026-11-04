import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Saved Dive Lab scenarios, held to the Dive Lab's own rules.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  const gf = {'kind': 'changeGf', 'gfLow': 30, 'gfHigh': 70};
  const loseBack = {'kind': 'loseTank', 'tankId': 't1'};

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await db
        .into(db.diveTanks)
        .insert(const DiveTanksCompanion(id: Value('t1'), diveId: Value('d1')));
    await db
        .into(db.diveTanks)
        .insert(const DiveTanksCompanion(id: Value('t2'), diveId: Value('d2')));
  });
  tearDown(() => tearDownTestDatabase());

  test('a new scenario replays from the start unless told', () async {
    final result = await h.run([
      createOp('dive_scenarios', {
        'dive_id': 'd1',
        'name': 'Lost back gas',
        'interventions': [loseBack, gf],
      }),
    ]);

    final doc = (await h.one('dive_scenarios', result.created.single.id))!;
    expect(doc['name'], 'Lost back gas');
    expect(doc['mode'], 'replay');
    expect(doc['branch_s'], 0);
    expect(doc['interventions'], [loseBack, gf]);
  });

  test('an update keeps what it does not name', () async {
    final created = await h.run([
      createOp('dive_scenarios', {
        'dive_id': 'd1',
        'name': 'Conservative',
        'notes': 'GF 30/70',
        'interventions': [gf],
      }),
    ]);
    final id = created.created.single.id;

    final plan = await h.preview([
      updateOp('dive_scenarios', id, {
        'branch_s': 900,
        // The same list, so nothing changes in it.
        'interventions': [gf],
      }),
    ]);
    expect(plan.items.single.fields.keys, ['branch_s']);
    await h.apply(plan);

    final doc = (await h.one('dive_scenarios', id))!;
    expect(doc['branch_s'], 900);
    expect(doc['notes'], 'GF 30/70');
    expect(doc['interventions'], [gf]);
  });

  // The Dive Lab moves a branch only within the dive, so a stored branch
  // past its end is one the app never writes.
  test('a branch past the end of the dive is blocked', () async {
    await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
      const DivesCompanion(runtime: Value(2700)),
    );
    Map<String, Object?> scenario(int branch) => createOp('dive_scenarios', {
      'dive_id': 'd1',
      'name': 'Late branch',
      'branch_s': branch,
    });

    final plan = await h.preview([scenario(2701), scenario(2700)]);

    expect(plan.items.first.block!.reason, BlockReason.invalidValue);
    expect(plan.items.first.block!.detail, contains('branch_s'));
    expect(plan.items.last.block, isNull);
  });

  test('interventions are held to the Dive Lab\'s rules', () async {
    final badShape = await h.preview([
      createOp('dive_scenarios', {
        'dive_id': 'd1',
        'name': 'Bad',
        'interventions': [
          {'kind': 'teleport'},
        ],
      }),
    ]);
    final shiftAndAbort = await h.preview([
      createOp('dive_scenarios', {
        'dive_id': 'd1',
        'name': 'Conflict',
        'interventions': [
          {'kind': 'shiftAscent', 'deltaSeconds': 120},
          {'kind': 'ascendNow'},
        ],
      }),
    ]);
    final otherDive = await h.preview([
      createOp('dive_scenarios', {
        'dive_id': 'd1',
        'name': 'Wrong tank',
        'interventions': [
          {'kind': 'loseTank', 'tankId': 't2'},
        ],
      }),
    ]);

    final blankNotes = await h.preview([
      createOp('dive_scenarios', {
        'dive_id': 'd1',
        'name': 'Blank',
        'notes': ' ',
      }),
    ]);

    for (final plan in [badShape, shiftAndAbort, otherDive, blankNotes]) {
      expect(plan.items.single.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a delete removes the scenario and a revert restores it', () async {
    final created = await h.run([
      createOp('dive_scenarios', {'dive_id': 'd1', 'name': 'Keep me'}),
    ]);
    final id = created.created.single.id;

    final result = await h.run([deleteOp('dive_scenarios', id)]);
    expect(await h.one('dive_scenarios', id), isNull);

    await h.revert(result);
    expect((await h.one('dive_scenarios', id))!['name'], 'Keep me');
  });
}
