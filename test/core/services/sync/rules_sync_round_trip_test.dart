import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Logbook rules and their run history travel through every per-record sync
/// arm unchanged (#3513).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  const t = 1790000000000;

  Map<String, dynamic> rule(String id, {String name = 'Deep'}) => {
    'id': id,
    'diverId': null,
    'subject': 'dives',
    'name': name,
    'enabled': true,
    'triggers': 'afterImport',
    'conditionJson':
        '{"version":1,"node":{"t":"cond","path":["depth"],"op":"gt",'
        '"value":{"k":"num","v":30.0}}}',
    'actionsJson':
        '{"version":1,"actions":[{"kind":"diveMembership",'
        '"collection":"diveTypes","mode":"add","ids":["deep"]}]}',
    'sortOrder': 0,
    'createdAt': t,
    'updatedAt': t,
    'hlc': null,
  };

  Map<String, dynamic> run(String id, {int? undoneAt}) => {
    'id': id,
    'diverId': null,
    'trigger': 'imported',
    'sourceLabel': 'Perdix 2',
    'deviceLabel': 'MacBook',
    'ranAt': t,
    'changedCount': 1,
    'undoneAt': undoneAt,
    'createdAt': t,
    'updatedAt': t,
    'hlc': null,
  };

  Map<String, dynamic> change(String id, String runId) => {
    'id': id,
    'runId': runId,
    'subject': 'dives',
    'targetId': 'd1',
    'ruleId': 'r1',
    'ruleName': 'Deep',
    'field': 'diveTypes',
    'beforeJson': '["recreational"]',
    'afterJson': '["deep","recreational"]',
    'sortOrder': 0,
    'createdAt': t,
    'updatedAt': t,
    'hlc': null,
  };

  test('the three entities are registered for sync', () {
    for (final e in ['rules', 'ruleRuns', 'ruleRunChanges']) {
      expect(SyncService.entityHasUpdatedAt[e], isTrue, reason: e);
      expect(const SyncData().toJson().keys, contains(e), reason: e);
    }
    expect(SyncService.parentRefs['ruleRunChanges'], [
      (field: 'runId', parent: 'ruleRuns', nullable: false),
    ]);
  });

  test('upsert, fetch and delete a rule', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('rules', rule('r1'));
    expect(
      (await s.fetchRecord('rules', 'r1'))!['actionsJson'],
      contains('deep'),
    );
    await s.upsertRecord('rules', rule('r1', name: 'Deeper'));
    expect((await s.fetchRecord('rules', 'r1'))!['name'], 'Deeper');
    await s.deleteRecord('rules', 'r1');
    expect(await s.fetchRecord('rules', 'r1'), isNull);
  });

  test('a run and its changes round-trip, and undo state syncs', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('ruleRuns', [run('run1')]);
    await s.upsertRecords('ruleRunChanges', [
      change('c1', 'run1'),
      change('c2', 'run1'),
    ]);
    expect(await s.recordIdsFor('ruleRuns'), {'run1'});
    expect(await s.recordIdsFor('ruleRunChanges'), {'c1', 'c2'});
    final fetched = await s.fetchRecords('ruleRunChanges', ['c1', 'c2', 'x']);
    expect(fetched['c1']!['afterJson'], '["deep","recreational"]');

    await s.upsertRecord('ruleRuns', run('run1', undoneAt: t + 1));
    expect((await s.fetchRecord('ruleRuns', 'run1'))!['undoneAt'], t + 1);
  });

  test('deleting a run removes its changes', () async {
    final s = SyncDataSerializer();
    await s.upsertRecord('ruleRuns', run('run1'));
    await s.upsertRecord('ruleRunChanges', change('c1', 'run1'));
    await s.deleteRecord('ruleRuns', 'run1');
    expect(await s.fetchRecord('ruleRunChanges', 'c1'), isNull);
  });
}
