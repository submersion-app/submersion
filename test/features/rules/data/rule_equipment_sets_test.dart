import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/dive_rule_applier.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

/// A rule that adds or removes a whole equipment set (#4284): the set's
/// current items arrive tagged with it, removing takes only what it brought,
/// and undo puts the dive's gear back as it was, provenance included.
void main() {
  late AppDatabase db;
  late RuleEngine engine;
  final undo = RuleUndoService();

  /// The dive's gear as `id:set`, `-` for none.
  Future<List<String>> gear() async => [
    for (final r
        in await db
            .customSelect(
              "SELECT equipment_id || ':' || COALESCE(via_set_id, '-') AS g "
              "FROM dive_equipment WHERE dive_id = 'd40' ORDER BY equipment_id",
            )
            .get())
      r.read<String>('g'),
  ];

  Future<void> handAdd(String id) => db.customStatement(
    "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d40', '$id')",
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd40', maxDepth: 40);
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('bcd', 'BCD', 'bcd', 0, 0), ('reg', 'Reg', 'regulator', 0, 0), "
      "('lamp', 'Lamp', 'light', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_sets (id, diver_id, name, created_at, updated_at) '
      "VALUES ('warm', 'me', 'Warm', 0, 0), ('empty', 'me', 'Empty', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_items (set_id, equipment_id) '
      "VALUES ('warm', 'bcd'), ('warm', 'reg')",
    );
    engine = RuleEngine(names: (_) async => NameIndex(const []));
  });
  tearDown(tearDownTestDatabase);

  Future<RuleRunResult> runRule(RuleAction action) async {
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Deep',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: [action],
    );
    return engine.run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
      ),
    );
  }

  DiveMembershipAction sets(MembershipMode mode, List<String> ids) =>
      DiveMembershipAction(DiveCollection.equipmentSets, mode, ids);

  test('adding a set puts its items on, tagged with it', () async {
    final result = await runRule(sets(MembershipMode.add, ['warm']));

    expect(await gear(), ['bcd:warm', 'reg:warm']);
    expect(result.changedTargetCount, 1);
    expect(result.changes.single.field, DiveCollection.equipment.name);
  });

  test('the set\'s contents are read when the rule runs', () async {
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Deep',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: [
        sets(MembershipMode.add, ['warm']),
      ],
    );
    await db.customStatement(
      'INSERT INTO equipment_set_items (set_id, equipment_id) '
      "VALUES ('warm', 'lamp')",
    );

    await engine.run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
      ),
    );

    expect(await gear(), ['bcd:warm', 'lamp:warm', 'reg:warm']);
  });

  test('removing a set keeps gear added by hand', () async {
    await handAdd('lamp');
    await db.customStatement(
      'INSERT INTO dive_equipment (dive_id, equipment_id, via_set_id) '
      "VALUES ('d40', 'bcd', 'warm'), ('d40', 'reg', 'warm')",
    );

    await runRule(sets(MembershipMode.remove, ['warm']));

    expect(await gear(), ['lamp:-']);
  });

  test('a deleted set is skipped and named', () async {
    final result = await runRule(sets(MembershipMode.add, ['gone']));

    expect(await gear(), isEmpty);
    expect(result.runId, isNull);
    expect(result.skippedActionRuleNames, ['Deep']);
  });

  test('an empty set changes nothing and is not reported', () async {
    final result = await runRule(sets(MembershipMode.add, ['empty']));

    expect(result.runId, isNull);
    expect(result.skippedActionRuleNames, isEmpty);
  });

  test('a dive that already has the set is left alone', () async {
    await db.customStatement(
      'INSERT INTO dive_equipment (dive_id, equipment_id, via_set_id) '
      "VALUES ('d40', 'bcd', 'warm'), ('d40', 'reg', 'warm')",
    );

    final result = await runRule(sets(MembershipMode.add, ['warm']));

    expect(result.runId, isNull);
  });

  test('the membership write and table name sets too', () async {
    final applier = DiveRuleApplier();
    expect(
      DiveRuleApplier.refTable(
        db,
        DiveCollection.equipmentSets,
      ).actualTableName,
      'equipment_sets',
    );

    await applier.writeMembership(
      DiveCollection.equipmentSets,
      add: true,
      diveIds: const ['d40'],
      ids: const ['warm'],
    );
    expect(await gear(), ['bcd:warm', 'reg:warm']);

    await applier.writeMembership(
      DiveCollection.equipmentSets,
      add: false,
      diveIds: const ['d40'],
      ids: const ['warm'],
    );
    expect(await gear(), isEmpty);
  });

  group('undo', () {
    test('takes the added set off again', () async {
      final result = await runRule(sets(MembershipMode.add, ['warm']));

      final undone = await undo.undo(result.runId!);

      expect(undone.restoredTargets, 1);
      expect(await gear(), isEmpty);
    });

    test('a hand-added item loses the set it took on', () async {
      await handAdd('bcd');
      final result = await runRule(sets(MembershipMode.add, ['warm']));
      expect(await gear(), ['bcd:warm', 'reg:warm']);

      await undo.undo(result.runId!);

      expect(await gear(), ['bcd:-']);
    });

    test('restores provenance when that was the only change', () async {
      await handAdd('bcd');
      await handAdd('reg');
      final result = await runRule(sets(MembershipMode.add, ['warm']));
      expect(await gear(), ['bcd:warm', 'reg:warm']);

      final undone = await undo.undo(result.runId!);

      expect(undone.restoredTargets, 1);
      expect(await gear(), ['bcd:-', 'reg:-']);
    });

    test('puts gear back untagged when its set was deleted since', () async {
      await db.customStatement(
        'INSERT INTO dive_equipment (dive_id, equipment_id, via_set_id) '
        "VALUES ('d40', 'bcd', 'warm'), ('d40', 'reg', 'warm')",
      );
      final result = await runRule(sets(MembershipMode.remove, ['warm']));
      await db.customStatement("DELETE FROM equipment_sets WHERE id = 'warm'");

      final undone = await undo.undo(result.runId!);

      expect(undone.restoredTargets, 1);
      expect(await gear(), ['bcd:-', 'reg:-']);
    });

    test('puts a removed set back with its provenance', () async {
      await db.customStatement(
        'INSERT INTO dive_equipment (dive_id, equipment_id, via_set_id) '
        "VALUES ('d40', 'bcd', 'warm'), ('d40', 'reg', 'warm')",
      );
      final result = await runRule(sets(MembershipMode.remove, ['warm']));
      expect(await gear(), isEmpty);

      await undo.undo(result.runId!);

      expect(await gear(), ['bcd:warm', 'reg:warm']);
    });

    test('a change stored under the set collection undoes as gear', () async {
      await db.customStatement(
        'INSERT INTO dive_equipment (dive_id, equipment_id, via_set_id) '
        "VALUES ('d40', 'bcd', 'warm'), ('d40', 'reg', 'warm')",
      );
      final result = await runRule(sets(MembershipMode.remove, ['warm']));
      await db.customStatement(
        "UPDATE rule_run_changes SET field = 'equipmentSets' "
        "WHERE run_id = '${result.runId}'",
      );

      final undone = await undo.undo(result.runId!);

      expect(undone.restoredTargets, 1);
      expect(await gear(), ['bcd:warm', 'reg:warm']);
    });
  });
}
