import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/families/custom_field_writes.dart';
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
        .into(db.diveCustomFields)
        .insert(
          DiveCustomFieldsCompanion.insert(
            id: 'f1',
            diveId: 'd1',
            fieldKey: 'Camera',
            fieldValue: const Value('GoPro'),
            createdAt: kSeedTime,
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a new field goes after the dive\'s fields', () async {
    final result = await h.run([
      createOp('dive_custom_fields', {
        'dive_id': 'd1',
        'key': 'Housing',
        'value': 'Nauticam',
      }),
    ]);

    final doc = (await h.one('dive_custom_fields', result.created.single.id))!;
    expect(doc['key'], 'Housing');
    expect(doc['value'], 'Nauticam');
    expect(doc['sort_order'], 1);
    expect(h.refreshed.single, {'d1'});
  });

  test('every field reaches its column', () async {
    const samples = <String, Object?>{
      'key': 'Lens',
      'value': 'Fisheye',
      'sort_order': 4,
    };
    expect(
      samples.keys.toSet(),
      CustomFieldWrites().fields.keys.toSet().difference({'dive_id'}),
    );

    await h.run([updateOp('dive_custom_fields', 'f1', samples)]);

    final doc = (await h.one('dive_custom_fields', 'f1'))!;
    for (final MapEntry(:key, :value) in samples.entries) {
      expect(doc[key], value, reason: key);
    }
  });

  test('a blank key is blocked', () async {
    final plan = await h.preview([
      createOp('dive_custom_fields', {'dive_id': 'd1', 'key': '  '}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a field is known by its key', () async {
    final plan = await h.preview([
      updateOp('dive_custom_fields', 'f1', {'value': 'Olympus'}),
    ]);

    expect(plan.items.single.title, 'Camera');
    expect(plan.items.single.parentTitle, 'Dive d1');
  });

  test('a delete removes the field and a revert restores it', () async {
    final result = await h.run([deleteOp('dive_custom_fields', 'f1')]);
    expect(await h.one('dive_custom_fields', 'f1'), isNull);

    await h.revert(result);

    expect((await h.one('dive_custom_fields', 'f1'))!['value'], 'GoPro');
  });
}
