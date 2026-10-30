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
import 'package:submersion/features/rules/domain/site_rule_field.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

void main() {
  late AppDatabase db;
  late RuleRepository rules;
  late RuleEngine engine;
  final undo = RuleUndoService();

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
    expect(await ruleDiveTypes(db, 'd35'), ['recreational', 'wreck']);
    expect(await ruleDiveTypes(db, 'd40'), ['recreational']);
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
    expect(await column('d40', 'notes'), 'Wall\n\nDeep dive and more');
    expect(result.skippedEditedTargets, 1);
  });

  test('appended notes come off only at a line boundary', () async {
    final run = await runRule(const AppendDiveNotesAction('Deep dive'));
    // d35's notes were empty, so the rule wrote just the text. The diver
    // then rewrote them into a sentence that happens to end the same way.
    await db.customStatement(
      "UPDATE dives SET notes = 'Not a Deep dive' WHERE id = 'd35'",
    );
    final result = await undo.undo(run);
    expect(await column('d35', 'notes'), 'Not a Deep dive');
    expect(await column('d40', 'notes'), 'Wall');
    expect(result.skippedEditedTargets, 1);
  });

  test('an appended line under a line added since comes off', () async {
    final run = await runRule(const AppendDiveNotesAction('Deep dive'));
    await db.customStatement(
      "UPDATE dives SET notes = 'Calm' || char(10) || notes WHERE id = 'd35'",
    );
    await undo.undo(run);
    expect(await column('d35', 'notes'), 'Calm');
  });

  test('a site added to a club library since is left alone', () async {
    await seedRuleSite(db, 's1');
    await rules.create(
      diverId: 'me',
      subject: RuleSubject.sites,
      name: 'Salt',
      triggers: const {RuleTrigger.afterImport},
      condition: null,
      actions: const [SetSiteFieldAction(SiteRuleField.waterType, 'salt')],
    );
    final ran = await engine.run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.sites: null},
      ),
    );
    // Adding a site to a library converts the same row in place.
    await db.customStatement(
      "UPDATE dive_sites SET shared_library_id = 'lib', diver_id = NULL "
      "WHERE id = 's1'",
    );
    final result = await undo.undo(ran.runId!);
    final water = await db
        .customSelect("SELECT water_type AS v FROM dive_sites WHERE id = 's1'")
        .getSingle();
    expect(water.data['v'], 'salt');
    expect(result.restoredTargets, 0);
    expect(result.skippedEditedTargets, 1);
  });

  test('a run whose dives were all deleted since is marked undone', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await db.customStatement('DELETE FROM dives');
    final result = await undo.undo(run);
    expect(result.nothingYet, isFalse);
    expect(result.skippedDeletedTargets, 2);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isTrue);
  });

  test('two rules appending to the same notes both undo', () async {
    await rules.create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'First',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: const [AppendDiveNotesAction('A')],
    );
    final run = await runRule(const AppendDiveNotesAction('B'), name: 'Second');
    expect(await column('d40', 'notes'), 'Wall\n\nA\n\nB');
    final result = await undo.undo(run);
    expect(await column('d40', 'notes'), 'Wall');
    expect(await column('d35', 'notes'), '');
    expect(result.skippedEditedTargets, 0);
  });

  test('a buddy whose role changed since is left alone', () async {
    await db.customStatement(
      "INSERT INTO buddies (id, name, created_at, updated_at) "
      "VALUES ('ann', 'Ann', 0, 0)",
    );
    final run = await runRule(
      const DiveMembershipAction(DiveCollection.buddies, MembershipMode.add, [
        'ann',
      ], buddyRoleId: 'instructor'),
    );
    await db.customStatement(
      "UPDATE dive_buddies SET role = 'buddy' WHERE dive_id = 'd40'",
    );
    final result = await undo.undo(run);
    final left = await db
        .customSelect('SELECT dive_id FROM dive_buddies ORDER BY dive_id')
        .get();
    expect([for (final r in left) r.read<String>('dive_id')], ['d40']);
    expect(result.restoredTargets, 1);
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

  test(
    'undo queues the derived-data refresh of the dives it restored',
    () async {
      final run = await runRule(
        const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
      );
      await db.customStatement(
        "UPDATE dives SET water_type = 'brackish' WHERE id = 'd35'",
      );
      final refreshed = <String>[];
      await RuleUndoService(afterDiveWrites: refreshed.addAll).undo(run);
      expect(refreshed, ['d40']);
    },
  );

  test('two undos at once undo the run once', () async {
    // The diver's own last line is the text the rule appends: a second
    // undo racing the first would take that line too.
    await db.customStatement(
      "UPDATE dives SET notes = 'Shore' || char(10) || 'Nitrox' "
      "WHERE id = 'd40'",
    );
    final run = await runRule(const AppendDiveNotesAction('Nitrox'));
    final results = await Future.wait([undo.undo(run), undo.undo(run)]);
    expect(await column('d40', 'notes'), 'Shore\nNitrox');
    expect(results.where((r) => r.alreadyUndone), hasLength(1));
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

  test('a run with only some changes synced stays undoable', () async {
    // Undoing the rows that arrived and marking the run undone would leave
    // the rest applied for good once they land.
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await db.customStatement(
      "DELETE FROM rule_run_changes WHERE target_id = 'd40'",
    );
    final result = await undo.undo(run);
    expect(result.nothingYet, isTrue);
    expect(result.restoredTargets, 0);
    expect(await column('d35', 'water_type'), 'salt');
    expect((await RuleRunRepository().getRun(run))!.isUndone, isFalse);
  });

  test('a change this version cannot read does not hold the run', () async {
    // A newer version's change row (an unknown subject) is counted as
    // arrived, so the run still undoes what this version can.
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    await db.customStatement(
      "UPDATE rule_runs SET changed_count = 3 WHERE id = '$run'",
    );
    await db.customStatement(
      'INSERT INTO rule_run_changes (id, run_id, subject, target_id, '
      'rule_name, field, before_json, after_json, created_at, updated_at) '
      "VALUES ('x', '$run', 'boats', 'b1', 'Deep', 'name', 'null', 'null', "
      '0, 0)',
    );
    final result = await undo.undo(run);
    expect(result.restoredTargets, 2);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isTrue);
  });

  test('undoing a trip change drops tank links into the trip left', () async {
    await db.customStatement(
      "INSERT INTO trips (id, name, start_date, end_date, created_at, "
      "updated_at) VALUES ('t1', 'Old', 0, 0, 0, 0), ('t2', 'New', 0, 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO trip_cylinders (id, trip_id, created_at, updated_at) '
      "VALUES ('slot2', 't2', 0, 0)",
    );
    await db.customStatement("UPDATE dives SET trip_id = 't1'");
    final run = await runRule(
      const SetDiveFieldAction(BulkField.trip, {'tripId': 't2'}),
    );
    // On the new trip, the diver links a tank to one of its cylinders.
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, trip_cylinder_id) '
      "VALUES ('tank1', 'd35', 'slot2')",
    );
    await undo.undo(run);
    expect(await column('d35', 'trip_id'), 't1');
    final link = await db
        .customSelect("SELECT trip_cylinder_id AS v FROM dive_tanks")
        .getSingle();
    expect(link.data['v'], isNull);
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
    // No sync can bring the old trip back: the run is done, not waiting.
    expect(result.nothingYet, isFalse);
    expect((await RuleRunRepository().getRun(run))!.isUndone, isTrue);
  });

  test('a failure other than a refused reference fails the undo', () async {
    final run = await runRule(
      const SetDiveFieldAction(BulkField.waterType, {'waterType': 'salt'}),
    );
    // A "before" the database cannot hold (dive_type is NOT NULL).
    await db.customStatement(
      'UPDATE rule_run_changes SET '
      "before_json = '{\"dive_type\":null}', "
      "after_json = '{\"dive_type\":\"recreational\"}'",
    );
    await expectLater(undo.undo(run), throwsA(anything));
    expect((await RuleRunRepository().getRun(run))!.isUndone, isFalse);
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
