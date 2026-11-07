import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Diver profiles, as the profile hub's edit pages keep them.
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

  test('a diver is created with settings listed, and edited', () async {
    final plan = await h.preview([
      createOp('divers', {'name': ' Ana ', 'email': ' ana@reef.co '}),
    ]);
    expect(plan.items.single.alsoCreates, {'diver_settings': 1});
    final id = (await h.apply(plan)).created.single.id;
    final created = (await h.one('divers', id))!;
    expect([created['name'], created['email']], ['Ana', 'ana@reef.co']);
    final settings = await (db.select(
      db.diverSettings,
    )..where((s) => s.diverId.equals(id))).get();
    expect(settings, hasLength(1));

    await h.run([
      updateOp('divers', id, {
        'phone': '  ',
        'medical_notes': ' Cleared ',
        'emergency_contact': {'name': 'Rui', 'phone': '+1 555', 'relation': ''},
        'prior_dive_count': 120,
        'prior_dive_time_s': 90 * 3600 + 30 * 60,
        'diving_since_date': '2004-01-01',
      }),
    ]);
    final edited = (await h.one('divers', id))!;
    expect(edited['phone'], isNull);
    expect(edited['medical_notes'], 'Cleared');
    expect(edited['emergency_contact'], {
      'name': 'Rui',
      'phone': '+1 555',
      'relation': null,
    });
    expect(edited['prior_dive_time_s'], 90 * 3600 + 30 * 60);
    expect(edited['diving_since_date'], '2004-01-01');
  });

  test('a diver delete is refused', () async {
    final plan = await h.preview([deleteOp('divers', kDiverB)]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('making a diver the default lists the one it takes over from', () async {
    final plan = await h.preview([
      updateOp('divers', kDiverB, {'is_default': true}),
      updateOp('divers', kDiverA, {'is_default': false}),
    ]);
    expect(plan.items.first.alsoChanges, {'divers': 1});
    expect(plan.items.last.block!.reason, BlockReason.invalidValue);

    await h.apply(
      await h.preview([
        updateOp('divers', kDiverB, {'is_default': true}),
      ]),
    );
    expect((await h.one('divers', kDiverA))!['is_default'], isFalse);
    expect((await h.one('divers', kDiverB))!['is_default'], isTrue);
  });

  test('an email without a dot is refused', () async {
    final plan = await h.preview([
      updateOp('divers', kDiverA, {'email': 'ana@reef'}),
      createOp('divers', {'email': 'ana@reef.co'}),
    ]);

    expect(plan.items.first.block!.reason, BlockReason.invalidValue);
    expect(plan.items.last.block!.reason, BlockReason.missingField);
  });

  test(
    'a prior time in part minutes, or a start year ahead, is refused',
    () async {
      final next = DateTime.now().year + 1;
      final plan = await h.preview([
        updateOp('divers', kDiverA, {'prior_dive_time_s': 3630}),
        updateOp('divers', kDiverA, {'diving_since_date': '$next-01-01'}),
        updateOp('divers', kDiverA, {'diving_since_date': '2004-06-01'}),
        updateOp('divers', kDiverA, {'prior_dive_count': -1}),
      ]);

      for (final item in plan.items) {
        expect(item.block, isNotNull, reason: '${item.values}');
      }
    },
  );
}
