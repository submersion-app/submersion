import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

RuleChange _change(String target, {String field = 'diveTypes'}) => RuleChange(
  subject: RuleSubject.dives,
  targetId: target,
  ruleId: 'r1',
  ruleName: 'Deep',
  field: field,
  before: const ['recreational'],
  after: const ['deep', 'recreational'],
);

void main() {
  late AppDatabase db;
  late RuleRunRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me', 'other']);
    repo = RuleRunRepository();
  });
  tearDown(tearDownTestDatabase);

  test('changedCount counts distinct targets, not changes', () async {
    final id = await repo.insertRun(
      diverId: 'me',
      trigger: RuleRunTrigger.imported,
      sourceLabel: 'Perdix 2',
      deviceLabel: 'MacBook',
      changes: [
        _change('d1'),
        _change('d1', field: 'tags'),
        _change('d2'),
      ],
    );
    final run = (await repo.getRun(id))!;
    expect(run.changedCount, 2);
    expect(run.trigger, RuleRunTrigger.imported);
    expect(run.sourceLabel, 'Perdix 2');
    expect(run.deviceLabel, 'MacBook');
    expect(run.undoneAt, isNull);
    final changes = await repo.getChanges(id);
    expect(changes.map((c) => c.targetId), ['d1', 'd1', 'd2']);
    expect(changes.first.after, ['deep', 'recreational']);
  });

  test('runs list newest first and only the diver\'s own', () async {
    final first = await repo.insertRun(
      diverId: 'me',
      trigger: RuleRunTrigger.onDemandAll,
      changes: [_change('d1')],
      ranAt: DateTime(2026, 10, 1),
    );
    final second = await repo.insertRun(
      diverId: 'me',
      trigger: RuleRunTrigger.createdByHand,
      changes: [_change('d2')],
      ranAt: DateTime(2026, 10, 2),
    );
    await repo.insertRun(
      diverId: 'other',
      trigger: RuleRunTrigger.imported,
      changes: [_change('d3')],
    );
    final runs = await repo.getRuns('me');
    expect(runs.map((r) => r.id), [second, first]);
    expect(runs.first.ruleNames, ['Deep']);
  });

  test('markUndone, deleteRun and deleteAllRuns', () async {
    final a = await repo.insertRun(
      diverId: 'me',
      trigger: RuleRunTrigger.imported,
      changes: [_change('d1')],
    );
    final b = await repo.insertRun(
      diverId: 'me',
      trigger: RuleRunTrigger.imported,
      changes: [_change('d2')],
    );
    await repo.markUndone(a, DateTime(2026, 10, 19));
    expect((await repo.getRun(a))!.undoneAt, DateTime(2026, 10, 19));

    await repo.deleteRun(a);
    expect(await repo.getRun(a), isNull);
    expect(await repo.getChanges(a), isEmpty);

    await repo.deleteAllRuns('me');
    expect(await repo.getRun(b), isNull);
    expect(await repo.getRuns('me'), isEmpty);
  });
}
