import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/dive_rule_applier.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

void main() {
  late AppDatabase db;
  late RuleRepository rules;
  late RuleEngine engine;
  final undo = RuleUndoService();

  Future<List<String>> typesOf(String diveId) async => [
    for (final r
        in await db
            .customSelect(
              'SELECT dive_type_id FROM dive_dive_types WHERE dive_id = ? '
              'ORDER BY dive_type_id',
              variables: [Variable.withString(diveId)],
            )
            .get())
      r.read<String>('dive_type_id'),
  ];

  Future<Object?> column(String diveId, String col) async =>
      (await db
              .customSelect(
                'SELECT $col AS v FROM dives WHERE id = ?',
                variables: [Variable.withString(diveId)],
              )
              .getSingle())
          .data['v'];

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd35', maxDepth: 35, waterType: 'fresh');
    await seedRuleDive(db, 'd40', maxDepth: 40, notes: 'Wall');
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('cold', 'Cold', 0, 0)",
    );
    rules = RuleRepository();
    engine = RuleEngine(names: (_) async => NameIndex(const []));
  });
  tearDown(tearDownTestDatabase);

  Future<String> runRule(RuleAction action, {String name = 'Deep'}) async {
    await rules.create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: name,
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: [action],
    );
    final r = await engine.run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
      ),
    );
    return r.runId!;
  }

  test('restores a field still at the rule\'s value', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    final result = await undo.undo(run);
    expect(result.restoredTargets, 2);
    expect(result.skippedEditedTargets, 0);
    expect(await column('d35', 'water_type'), 'fresh');
    expect(await column('d40', 'water_type'), isNull);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isTrue);
  });

  test('skips a field edited since and reports it', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await db.customStatement(
      "UPDATE dives SET water_type = 'brackish' WHERE id = 'd35'",
    );
    final result = await undo.undo(run);
    expect(result.restoredTargets, 1);
    expect(result.skippedEditedTargets, 1);
    expect(await column('d35', 'water_type'), 'brackish');
  });

  test('membership undo removes the addition but keeps a later one', () async {
    final run = await runRule(
      const DiveMembershipAction(DiveCollection.diveTypes, MembershipMode.add, [
        'deep',
      ]),
    );
    await db.customStatement(
      "INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) "
      "VALUES ('later', 'd35', 'wreck', 0)",
    );
    await undo.undo(run);
    expect(await typesOf('d35'), ['recreational', 'wreck']);
    expect(await typesOf('d40'), ['recreational']);
  });

  test('re-adds a removed tag only if still absent', () async {
    await db.customStatement(
      "INSERT INTO dive_tags (id, dive_id, tag_id, created_at) "
      "VALUES ('t1', 'd35', 'cold', 0), ('t2', 'd40', 'cold', 0)",
    );
    final run = await runRule(
      const DiveMembershipAction(DiveCollection.tags, MembershipMode.remove, [
        'cold',
      ]),
    );
    await db.customStatement(
      "INSERT INTO dive_tags (id, dive_id, tag_id, created_at) "
      "VALUES ('t3', 'd40', 'cold', 0)",
    );
    final result = await undo.undo(run);
    expect(result.restoredTargets, 1);
    expect(result.skippedEditedTargets, 1);
    final d40 = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM dive_tags WHERE dive_id = 'd40'",
        )
        .getSingle();
    expect(d40.read<int>('n'), 1);
  });

  test('strips appended notes only while they still end the text', () async {
    final run = await runRule(const AppendDiveNotesAction('Deep dive'));
    await db.customStatement(
      "UPDATE dives SET notes = notes || ' and more' WHERE id = 'd40'",
    );
    final result = await undo.undo(run);
    expect(await column('d35', 'notes'), '');
    expect(await column('d40', 'notes'), 'Wall\nDeep dive and more');
    expect(result.skippedEditedTargets, 1);
  });

  test('a deleted dive counts as skipped', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await db.customStatement("DELETE FROM dives WHERE id = 'd35'");
    final result = await undo.undo(run);
    expect(result.skippedDeletedTargets, 1);
    expect(result.restoredTargets, 1);
  });

  test('nothing revertible leaves the run undoable', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await db.customStatement("UPDATE dives SET water_type = 'brackish'");
    final result = await undo.undo(run);
    expect(result.nothingYet, isTrue);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isFalse);
  });

  test('a second undo is refused', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await undo.undo(run);
    final again = await undo.undo(run);
    expect(again.alreadyUndone, isTrue);
    expect(again.restoredTargets, 0);
  });

  test('undo works after the rule was deleted', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
      name: 'Salty',
    );
    final all = await rules.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: NameIndex(const []),
    );
    await rules.delete(all.single.id);
    final changes = await RuleRunRepository().getChanges(run);
    expect(changes.first.ruleName, 'Salty');
    final result = await undo.undo(run);
    expect(result.restoredTargets, 2);
  });

  test('a run whose changes have not synced yet stays undoable', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await db.customStatement('DELETE FROM rule_run_changes');
    final result = await undo.undo(run);
    expect(result.nothingYet, isTrue);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isFalse);
  });

  test('a change that can no longer be written is skipped, not fatal', () async {
    await db.customStatement(
      "INSERT INTO trips (id, name, start_date, end_date, created_at, "
      "updated_at) VALUES ('t1', 'Old', 0, 0, 0, 0), ('t2', 'New', 0, 0, 0, 0)",
    );
    await db.customStatement("UPDATE dives SET trip_id = 't1'");
    final run = await runRule(
      const SetDiveFieldAction(BulkField.trip, {'tripId': 't2'}),
    );
    // The trip the dives were on before is gone; restoring it would break
    // the foreign key.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement("DELETE FROM trips WHERE id = 't1'");
    await db.customStatement('PRAGMA foreign_keys = ON');
    final result = await undo.undo(run);
    expect(result.skippedEditedTargets, 2);
    expect(await column('d35', 'trip_id'), 't2');
  });

  test('undoing several runs reports their combined outcome', () {
    final merged = RuleUndoResult.combine(const [
      RuleUndoResult(restoredTargets: 2),
      RuleUndoResult(restoredTargets: 1, skippedEditedTargets: 3),
      RuleUndoResult(alreadyUndone: true),
    ]);
    expect(merged.restoredTargets, 3);
    expect(merged.skippedEditedTargets, 3);
    expect(merged.nothingYet, isFalse);
    expect(merged.alreadyUndone, isFalse);
    expect(
      RuleUndoResult.combine(const [
        RuleUndoResult(nothingYet: true),
        RuleUndoResult(alreadyUndone: true),
      ]).nothingYet,
      isTrue,
    );
    expect(
      RuleUndoResult.combine(const [
        RuleUndoResult(alreadyUndone: true),
        RuleUndoResult(alreadyUndone: true),
      ]).alreadyUndone,
      isTrue,
    );
  });

  test('an unexpected failure is reported, not counted as an edit', () async {
    final run = await runRule(
      const DiveMembershipAction(DiveCollection.tags, MembershipMode.add, [
        'cold',
      ]),
    );
    final broken = RuleUndoService(dives: _ThrowingDiveApplier());
    await expectLater(broken.undo(run), throwsStateError);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isFalse);
  });
}

class _ThrowingDiveApplier extends DiveRuleApplier {
  @override
  Future<Map<String, List<Object>>> members(
    DiveCollection c,
    List<String> diveIds,
  ) => throw StateError('broken');
}
