import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Incidents and emergency chambers, as the safety pages keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Regulator',
            type: 'regulator',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('an incident is logged, edited and deleted', () async {
    final plan = await h.preview([
      createOp('incidents', {
        'narrative': ' Free flow at 20 m ',
        'occurred_time': '2024-03-14T09:40:00Z',
        'dive_id': 'd1',
        'equipment_id': 'reg',
      }),
    ]);
    final fields = plan.items.single.fields;
    expect(
      [fields['category']!.newValue, fields['severity']!.newValue],
      ['other', 'minor'],
    );
    final id = (await h.apply(plan)).created.single.id;
    expect((await h.one('incidents', id))!['narrative'], 'Free flow at 20 m');

    await h.run([
      updateOp('incidents', id, {
        'severity': 'moderate',
        'lessons_learned': '  ',
      }),
    ]);
    final edited = (await h.one('incidents', id))!;
    expect([edited['severity'], edited['lessons_learned']], ['moderate', null]);

    await h.run([deleteOp('incidents', id)]);
    expect(await h.one('incidents', id), isNull);
  });

  test('an incident linked to an ok check-in is refused', () async {
    final ok = await make('equipment_observations', {
      'equipment_id': 'reg',
      'status': 'ok',
    });

    final plan = await h.preview([
      createOp('incidents', {
        'narrative': 'Leak',
        'occurred_time': '2024-03-14T09:40:00Z',
        'equipment_id': 'reg',
        'observation_id': ok,
      }),
      createOp('incidents', {
        'narrative': 'Later',
        'occurred_time': '${DateTime.now().year + 1}-01-01T00:00:00Z',
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a chamber is added and deleted; a built-in is refused', () async {
    final id = await make('emergency_chambers', {
      'name': ' Hyperbaric Centre ',
      'country': 'eg',
      'phone': '+20 123',
      'city': ' ',
    });
    final chamber = (await h.one('emergency_chambers', id))!;
    expect(
      [chamber['name'], chamber['country'], chamber['city']],
      ['Hyperbaric Centre', 'EG', null],
    );
    final edit = await h.preview([
      updateOp('emergency_chambers', id, {'phone': '+20 999'}),
    ]);
    expect(edit.items.single.block!.reason, BlockReason.notPermitted);

    await h.run([deleteOp('emergency_chambers', id)]);
    expect(await h.one('emergency_chambers', id), isNull);

    final builtIn = await h.preview([
      deleteOp('emergency_chambers', 'builtin-egypt-1'),
    ]);
    expect(builtIn.items.single.block, isNotNull);
  });
}
