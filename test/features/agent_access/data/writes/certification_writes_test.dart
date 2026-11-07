import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Certification cards, as the certification edit page keeps them.
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
  });
  tearDown(() => tearDownTestDatabase());

  test(
    'a certification is created, edited and deleted with its currency listed',
    () async {
      final plan = await h.preview([
        createOp('certifications', {
          'level': 'openWater',
          'card_number': ' 123 ',
          'issue_date': '2020-05-01',
        }),
      ]);
      expect(plan.items.single.fields['agency']!.newValue, 'padi');
      final id = (await h.apply(plan)).created.single.id;
      final card = (await h.one('certifications', id))!;
      expect(card['diver_id'], kDiverA);
      expect([card['card_number'], card['issue_date']], ['123', '2020-05-01']);

      await h.run([
        updateOp('certifications', id, {
          'name': 'My OW',
          'card_number': '',
          'expiry_date': '2030-01-01',
        }),
      ]);
      final edited = (await h.one('certifications', id))!;
      expect(edited['name'], 'My OW');
      expect(edited['card_number'], isNull);

      await make('currency_events', {
        'certification_id': id,
        'event_date': '2024-01-10',
      });
      await make('currency_prefs', {
        'certification_id': id,
        'rule_id': 'padi_reactivate',
        'muted': true,
      });
      final drop = await h.preview([deleteOp('certifications', id)]);
      expect(drop.items.single.reach.parts, {
        'certification_currency_events': 1,
        'certification_currency_prefs': 1,
      });
      await h.apply(drop);
      expect(await h.one('certifications', id), isNull);
    },
  );

  test('a certification with neither title nor level is refused', () async {
    final plan = await h.preview([
      createOp('certifications', {'name': '  '}),
      createOp('certifications', {'name': 'Nitrox', 'agency': 'nobody'}),
      createOp('certifications', {
        'level': 'openWater',
        'issue_date': '1949-12-31',
      }),
    ]);

    expect(plan.items[0].block!.reason, BlockReason.missingField);
    expect(plan.items[1].block!.reason, BlockReason.invalidValue);
    expect(plan.items[2].block!.reason, BlockReason.invalidValue);
  });

  test('an instructor copies the buddy\'s name', () async {
    final buddy = await make('buddies', {'name': 'Rui'});
    await make('certifications', {
      'buddy_id': buddy,
      'level': 'instructor',
      'card_number': 'I-77',
    });

    final plan = await h.preview([
      createOp('certifications', {
        'level': 'openWater',
        'instructor_id': buddy,
      }),
    ]);
    final fields = plan.items.single.fields;
    expect(fields['instructor_name']!.newValue, 'Rui');
    expect(fields['instructor_number']!.newValue, 'I-77');
    expect(fields['instructor_name']!.indirect, isTrue);
    final id = (await h.apply(plan)).created.single.id;

    final card = (await h.one('certifications', id))!;
    expect([card['instructor_id'], card['instructor_name']], [buddy, 'Rui']);
  });

  test('a buddy\'s card belongs to the buddy, never the diver too', () async {
    final buddy = await make('buddies', {'name': 'Rui'});
    final id = await make('certifications', {
      'buddy_id': buddy,
      'level': 'openWater',
    });

    final card = (await h.one('certifications', id))!;
    expect([card['diver_id'], card['buddy_id']], [null, buddy]);
    final plan = await h.preview([
      updateOp('certifications', id, {'notes': 'Checked'}),
    ]);
    expect(plan.items.single.block, isNull);
    expect(plan.items.single.diverId, kDiverA);
  });
}
