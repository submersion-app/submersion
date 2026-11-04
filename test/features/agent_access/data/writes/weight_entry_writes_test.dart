import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A diver's weight log, as the weight sheet keeps it: a day and a weight.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a weight entry is logged, edited and deleted', () async {
    final id = (await h.run([
      createOp('weight_entries', {
        'weight_kg': 81.5,
        'height_cm': 180,
        'measured_at': '2024-03-01',
      }, diver: kDiverB),
    ])).created.single.id;
    final row = await (db.select(
      db.diverWeightEntries,
    )..where((e) => e.id.equals(id))).getSingle();
    expect(row.diverId, kDiverB);
    expect(
      DateTime.fromMillisecondsSinceEpoch(row.measuredAt),
      DateTime(2024, 3, 1),
    );

    final same = await h.preview([
      updateOp('weight_entries', id, {'measured_at': '2024-03-01'}),
    ]);
    expect(same.unchanged.single.id, id);

    await h.run([
      updateOp('weight_entries', id, {'weight_kg': 80.0}),
    ]);
    expect(
      (await h.one('weight_entries', id, diverId: kDiverB))!['weight_kg'],
      80.0,
    );

    await h.run([deleteOp('weight_entries', id)]);
    expect(await h.one('weight_entries', id, diverId: kDiverB), isNull);
  });

  test('a weight of nothing, or a day ahead, is refused', () async {
    final plan = await h.preview([
      createOp('weight_entries', {'weight_kg': 0, 'measured_at': '2024-03-01'}),
      createOp('weight_entries', {
        'weight_kg': 80,
        'measured_at': '${DateTime.now().year + 1}-01-01',
      }),
      createOp('weight_entries', {
        'weight_kg': 80,
        'measured_at': '1949-12-31',
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block, isNotNull, reason: '${item.values}');
    }
  });
}
