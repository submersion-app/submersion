import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Automation rules, as the rule edit page saves them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  const notes = {
    'version': 1,
    'actions': [
      {'kind': 'appendDiveNotes', 'text': 'Checked'},
    ],
  };

  Future<String> make(Map<String, Object?> values) async =>
      (await h.run([createOp('rules', values)])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a rule is created, disabled, reordered and deleted', () async {
    final plan = await h.preview([
      createOp('rules', {
        'subject': 'dives',
        'name': ' Notes ',
        'actions': notes,
      }),
    ]);
    expect(plan.items.single.fields['triggers']!.newValue, ['afterImport']);
    final first = (await h.apply(plan)).created.single.id;
    final second = await make({
      'subject': 'dives',
      'name': 'Second',
      'actions': notes,
      'condition': {
        'version': 1,
        'node': {
          't': 'text',
          'words': ['reef'],
        },
      },
    });
    final rule = (await h.one('rules', first))!;
    expect([rule['name'], rule['enabled']], ['Notes', true]);

    await h.run([
      updateOp('rules', first, {'enabled': false}),
    ]);
    await h.run([
      updateOp('rules', second, {'sort_order': 0}),
    ]);
    expect((await h.one('rules', first))!['enabled'], isFalse);
    expect((await h.one('rules', second))!['sort_order'], 0);
    expect((await h.one('rules', first))!['sort_order'], 1);

    final copy = await make({'duplicate_of': first});
    expect((await h.one('rules', copy))!['actions'], notes);

    await h.run([deleteOp('rules', first)]);
    expect(await h.one('rules', first), isNull);
  });

  test('a rule with no action is refused', () async {
    final plan = await h.preview([
      createOp('rules', {
        'subject': 'dives',
        'name': 'Empty',
        'actions': {'version': 1, 'actions': <Object>[]},
      }),
      createOp('rules', {
        'subject': 'dives',
        'name': 'Future',
        'actions': {'version': 99, 'actions': <Object>[]},
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a rule\'s condition that does not parse is refused', () async {
    final plan = await h.preview([
      createOp('rules', {
        'subject': 'dives',
        'name': 'Bad',
        'actions': notes,
        'condition': {
          'version': 1,
          'node': {
            't': 'cond',
            'path': ['nothing_here'],
            'op': 'eq',
            'value': {'k': 'num', 'v': 1},
          },
        },
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });
}
