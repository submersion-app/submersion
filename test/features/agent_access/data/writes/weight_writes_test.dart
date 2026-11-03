import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/weight_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await db
        .into(db.diveWeights)
        .insert(
          DiveWeightsCompanion.insert(
            id: 'w1',
            diveId: 'd2',
            weightType: 'belt',
            amountKg: 6,
            createdAt: kSeedTime,
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a new weight is a belt unless named otherwise', () async {
    final result = await h.run([
      createOp('dive_weights', {'dive_id': 'd1', 'amount_kg': 2.0}),
    ]);

    final doc = (await h.one('dive_weights', result.created.single.id))!;
    expect(doc['type'], 'belt');
    expect(doc['amount_kg'], 2.0);
    expect(doc['label'], '');
    expect(h.refreshed.single, {'d1'});
  });

  test('a new weight needs its amount', () async {
    final plan = await h.preview([
      createOp('dive_weights', {'dive_id': 'd1'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.missingField);
  });

  test('every field reaches its column', () async {
    const samples = <String, Object?>{
      'type': 'integrated',
      'amount_kg': 3.5,
      'label': 'Pockets',
      'notes': 'Two each side',
    };
    expect(
      samples.keys.toSet(),
      WeightWrites().fields.keys.toSet().difference({'dive_id'}),
    );

    await h.run([updateOp('dive_weights', 'w1', samples)]);

    final doc = (await h.one('dive_weights', 'w1', diverId: kDiverB))!;
    for (final MapEntry(:key, :value) in samples.entries) {
      expect(doc[key], value, reason: key);
    }
  });

  test('a weight of another profile\'s dive is that profile\'s', () async {
    final plan = await h.preview([
      updateOp('dive_weights', 'w1', {'amount_kg': 5.0}),
    ]);

    expect(plan.items.single.diverId, kDiverB);
    // Unlabelled, so untitled: the dialog names it by its kind.
    expect(plan.items.single.title, isNull);
  });

  test('a label that is not trimmed is blocked', () async {
    final plan = await h.preview([
      updateOp('dive_weights', 'w1', {'label': ' Pockets'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a delete removes the weight and a revert restores it', () async {
    final result = await h.run([deleteOp('dive_weights', 'w1')]);
    expect(await h.one('dive_weights', 'w1', diverId: kDiverB), isNull);
    // Its dive's weighting figures are worked out again.
    expect(h.refreshed.single, {'d2'});

    await h.revert(result);

    expect(
      (await h.one('dive_weights', 'w1', diverId: kDiverB))!['amount_kg'],
      6.0,
    );
  });
}
