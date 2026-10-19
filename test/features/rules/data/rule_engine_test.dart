import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

void main() {
  late AppDatabase db;
  late RuleRepository rules;
  late RuleEngine engine;

  final gearDrysuit = ConditionNode(
    FieldPath(['gear', 'name']),
    QueryOp.eq,
    const StringValue('Drysuit'),
  );

  Future<List<String>> tagsOf(String diveId) async => [
    for (final r
        in await db
            .customSelect(
              'SELECT tag_id FROM dive_tags WHERE dive_id = ? ORDER BY tag_id',
              variables: [Variable.withString(diveId)],
            )
            .get())
      r.read<String>('tag_id'),
  ];

  Future<int> runCount() async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM rule_runs').getSingle())
          .read<int>('n');

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd20', maxDepth: 20);
    await seedRuleDive(db, 'd35', maxDepth: 35);
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('dry', 'Drysuit', 'drysuit', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('cold', 'Cold', 0, 0)",
    );
    rules = RuleRepository();
    engine = RuleEngine(
      names: (_) async => NameIndex(const []),
      deviceLabel: () async => 'Test device',
    );
  });
  tearDown(tearDownTestDatabase);

  Future<String> rule(
    String name,
    QueryNode? condition,
    RuleAction action, {
    Set<RuleTrigger> triggers = const {RuleTrigger.afterImport},
  }) => rules.create(
    diverId: 'me',
    subject: RuleSubject.dives,
    name: name,
    triggers: triggers,
    condition: condition,
    actions: [action],
  );

  const addDrysuit = DiveMembershipAction(
    DiveCollection.equipment,
    MembershipMode.add,
    ['dry'],
  );
  const tagCold = DiveMembershipAction(
    DiveCollection.tags,
    MembershipMode.add,
    ['cold'],
  );

  RuleRunRequest request({
    RuleRunTrigger trigger = RuleRunTrigger.onDemandAll,
    Set<String>? dives,
    List<String>? onlyRuleIds,
  }) => RuleRunRequest(
    diverId: 'me',
    trigger: trigger,
    targets: {RuleSubject.dives: dives},
    onlyRuleIds: onlyRuleIds,
  );

  test('a later rule sees what an earlier rule added', () async {
    await rule('Drysuit when deep', depthOver(30), addDrysuit);
    await rule('Cold when drysuit', gearDrysuit, tagCold);
    final result = await engine.run(request());
    expect(await tagsOf('d35'), ['cold']);
    expect(await tagsOf('d20'), isEmpty);
    expect(result.changedTargetCount, 1);
    expect(result.changedCountByRule, {
      'Drysuit when deep': 1,
      'Cold when drysuit': 1,
    });
    expect(result.runId, isNotNull);
  });

  test('swapping the order leaves the tag off', () async {
    final first = await rule('Cold when drysuit', gearDrysuit, tagCold);
    final second = await rule('Drysuit when deep', depthOver(30), addDrysuit);
    await rules.reorder([first, second]);
    await engine.run(request());
    expect(await tagsOf('d35'), isEmpty);
  });

  test('preview changes nothing and matches the later run', () async {
    await rule('Drysuit when deep', depthOver(30), addDrysuit);
    await rule('Cold when drysuit', gearDrysuit, tagCold);
    final preview = await engine.preview(request());
    expect(preview.runId, isNull);
    expect(await tagsOf('d35'), isEmpty);
    expect(await runCount(), 0);
    final run = await engine.run(request());
    expect(
      run.changes.map((c) => '${c.targetId}:${c.field}:${c.after}'),
      preview.changes.map((c) => '${c.targetId}:${c.field}:${c.after}'),
    );
  });

  test('nothing changed writes no run and returns no id', () async {
    await rule('Cold when very deep', depthOver(60), tagCold);
    final result = await engine.run(request());
    expect(result.runId, isNull);
    expect(result.changes, isEmpty);
    expect(await runCount(), 0);
  });

  test('a disabled rule runs only when named', () async {
    final id = await rule('Cold when deep', depthOver(30), tagCold);
    await rules.setEnabled(id, false);
    await engine.run(request());
    expect(await tagsOf('d35'), isEmpty);
    await engine.run(request(onlyRuleIds: [id]));
    expect(await tagsOf('d35'), ['cold']);
  });

  test('triggers pick which rules run automatically', () async {
    await rule('Import only', depthOver(30), tagCold);
    await engine.run(request(trigger: RuleRunTrigger.createdByHand));
    expect(await tagsOf('d35'), isEmpty);
    await engine.run(request(trigger: RuleRunTrigger.imported));
    expect(await tagsOf('d35'), ['cold']);
  });

  test('an unrunnable rule is reported while the others run', () async {
    await rule(
      'Ghost site',
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('gone', 'Gone Reef'),
      ),
      tagCold,
    );
    await rule('Cold when deep', depthOver(30), tagCold);
    final result = await engine.run(request());
    expect(result.skippedRuleNames, ['Ghost site']);
    expect(await tagsOf('d35'), ['cold']);
  });

  test('targets limit the run to the given dives', () async {
    await rule('Cold always', null, tagCold);
    final result = await engine.run(request(dives: {'d20'}));
    expect(await tagsOf('d20'), ['cold']);
    expect(await tagsOf('d35'), isEmpty);
    expect(result.targetCount, 1);
  });

  test('a run records the device and notifies sync', () async {
    await rule('Cold when deep', depthOver(30), tagCold);
    // Let the create's own notification drain before counting.
    await Future<void>.delayed(Duration.zero);
    var notes = 0;
    final sub = SyncEventBus.changes.listen((_) => notes++);
    addTearDown(sub.cancel);
    final result = await engine.run(request());
    await Future<void>.delayed(Duration.zero);
    // Sync listeners are debounced; a bulk tag write notifies on its own too.
    expect(notes, greaterThanOrEqualTo(1));
    final run = await RuleRunRepository().getRun(result.runId!);
    expect(run!.deviceLabel, 'Test device');
    expect(run.changedCount, 1);
  });

  test('names resolve before the transaction opens (no deadlock)', () async {
    await rule('Cold when deep', depthOver(30), tagCold);
    // A name index rebuilding OUTSIDE the transaction zone (as the live
    // provider does) must not be awaited while the transaction holds the
    // connection lock.
    final e = RuleEngine(
      names: (_) {
        final c = Completer<NameIndex>();
        Zone.root.run(
          () => db
              .customSelect('SELECT 1')
              .get()
              .then((_) => c.complete(NameIndex(const []))),
        );
        return c.future;
      },
      deviceLabel: () async => 'x',
    );
    final preview = await e
        .preview(request())
        .timeout(const Duration(seconds: 5));
    expect(preview.changedAnything, isTrue);
    final run = await e.run(request()).timeout(const Duration(seconds: 5));
    expect(run.changedAnything, isTrue);
  });

  test('names are resolved for the request\'s diver', () async {
    final seen = <String>[];
    await RuleEngine(
      names: (diverId) async {
        seen.add(diverId);
        return NameIndex(const []);
      },
      deviceLabel: () async => 'x',
    ).preview(request());
    expect(seen, ['me']);
  });

  test('a preview notifies nothing', () async {
    await rule('Cold when deep', depthOver(30), tagCold);
    await Future<void>.delayed(Duration.zero);
    var notes = 0;
    final sub = SyncEventBus.changes.listen((_) => notes++);
    addTearDown(sub.cancel);
    final preview = await engine.preview(request());
    await Future<void>.delayed(Duration.zero);
    expect(preview.changedAnything, isTrue);
    expect(notes, 0);
  });
}
