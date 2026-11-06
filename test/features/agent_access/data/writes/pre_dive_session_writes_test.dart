import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import 'child_write_harness.dart';

/// Pre-dive checklist runs, as the start sheet and the runner keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  Future<String> make(String entity, Map<String, Object?> values) async =>
      (await h.run([createOp(entity, values)])).created.single.id;

  Future<String> template({bool strict = false}) => make('pre_dive_templates', {
    'name': 'Basic',
    'strict_order': strict,
    'items': [
      {'title': 'Air on', 'is_required': true},
      {'title': 'BCD inflates', 'is_required': true},
      {'title': 'Spare mask'},
    ],
  });

  Future<List<String>> items(String session) =>
      h.records.list('pre_dive_session_items', parentId: session);

  Map<String, Object?> state(String item, String value) =>
      updateOp('pre_dive_session_items', item, {'state': value});

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a session starts from a template and runs to complete', () async {
    final session = await make('pre_dive_sessions', {
      'template_id': await template(),
    });
    final run = (await h.one('pre_dive_sessions', session))!;
    expect([run['template_name'], run['status']], ['Basic', 'inProgress']);
    final ids = await items(session);
    expect(ids, hasLength(3));

    await h.run([state(ids[0], 'done')]);
    await h.run([
      {
        ...state(ids[1], 'flagged'),
        'fields': {'state': 'flagged', 'note': 'Slow leak'},
      },
    ]);
    await h.run([
      updateOp('pre_dive_sessions', session, {'status': 'completed'}),
    ]);

    expect((await h.one('pre_dive_sessions', session))!['status'], 'completed');
    final flagged = (await h.one('pre_dive_session_items', ids[1]))!;
    expect([flagged['state'], flagged['note']], ['flagged', 'Slow leak']);
  });

  // The runner writes a reading over the last one and never clears it, so
  // null is not offered: a preview that lists it cleared would not hold.
  test('a reading is replaced, never cleared', () async {
    final session = await make('pre_dive_sessions', {
      'template_id': await template(),
    });
    final first = (await items(session)).first;
    await h.run([
      updateOp('pre_dive_session_items', first, {
        'value_number': 210.0,
        'value_text': 'Full',
      }),
    ]);

    for (final key in const ['value_number', 'value_text']) {
      final plan = await h.preview([
        updateOp('pre_dive_session_items', first, {key: null}),
      ]);
      expect(plan.items.single.block!.reason, BlockReason.invalidValue);
    }
  });

  test('completing with a required item pending is refused', () async {
    final session = await make('pre_dive_sessions', {
      'template_id': await template(),
    });

    final plan = await h.preview([
      updateOp('pre_dive_sessions', session, {'status': 'completed'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a locked session refuses item changes but links to a dive', () async {
    final session = await make('pre_dive_sessions', {
      'template_id': await template(),
    });
    await h.run([
      updateOp('pre_dive_sessions', session, {'status': 'aborted'}),
    ]);
    final ids = await items(session);

    final edit = await h.preview([state(ids[0], 'done')]);
    expect(edit.items.single.block!.reason, BlockReason.notPermitted);

    await h.run([
      updateOp('pre_dive_sessions', session, {'dive_id': 'd1'}),
    ]);
    expect((await h.one('pre_dive_sessions', session))!['dive_id'], 'd1');

    final other = await make('pre_dive_sessions', {
      'template_id': await template(),
    });
    final taken = await h.preview([
      updateOp('pre_dive_sessions', other, {'dive_id': 'd1'}),
    ]);
    expect(taken.items.single.block!.reason, BlockReason.duplicateRecord);
  });

  test('strict order refuses an item out of turn', () async {
    final session = await make('pre_dive_sessions', {
      'template_id': await template(strict: true),
    });
    final ids = await items(session);

    final plan = await h.preview([state(ids[1], 'done')]);
    expect(plan.items.single.block!.reason, BlockReason.notPermitted);

    await h.run([state(ids[0], 'done')]);
    await h.run([state(ids[1], 'done')]);
    expect((await h.one('pre_dive_session_items', ids[1]))!['state'], 'done');
  });
}
