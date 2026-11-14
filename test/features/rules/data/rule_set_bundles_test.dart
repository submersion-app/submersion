import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/data/services/rule_undo_service.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

/// A rule that adds an equipment set also applies the weights and cylinders
/// the set carries (issue #4525), records them, and undoes them.
void main() {
  late AppDatabase db;
  late RuleEngine engine;
  final undo = RuleUndoService();

  Future<List<double>> weights(String diveId) async => [
    for (final r in await (db.select(
      db.diveWeights,
    )..where((w) => w.diveId.equals(diveId))).get())
      r.amountKg,
  ];

  Future<List<DiveTank>> tanks(String diveId) =>
      (db.select(db.diveTanks)..where((t) => t.diveId.equals(diveId))).get();

  Future<int> gearCount(String diveId) async => (await (db.select(
    db.diveEquipment,
  )..where((r) => r.diveId.equals(diveId))).get()).length;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    // d40 has nothing; d45 has its own lead and a tank with no size.
    await seedRuleDive(db, 'd40', maxDepth: 40);
    await seedRuleDive(db, 'd45', maxDepth: 45);
    await db.customStatement(
      'INSERT INTO dive_weights (id, dive_id, weight_type, amount_kg, '
      "created_at) VALUES ('own', 'd45', 'belt', 5.0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, tank_role, o2_percent, '
      "tank_order) VALUES ('t45', 'd45', 'backGas', 28.0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('bcd', 'me', 'BCD', 'bcd', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_sets (id, diver_id, name, created_at, updated_at) '
      "VALUES ('warm', 'me', 'Warm', 0, 0), ('lead', 'me', 'Lead', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_items (set_id, equipment_id) '
      "VALUES ('warm', 'bcd')",
    );
    await db.customStatement(
      'INSERT INTO weight_presets (id, diver_id, display_name, created_at, '
      "updated_at) VALUES ('belt8', 'me', 'Belt', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO weight_preset_entries (id, preset_id, weight_type, '
      "amount_kg, created_at) VALUES ('e1', 'belt8', 'belt', 3.63, 0)",
    );
    await db.customStatement(
      'INSERT INTO cylinder_configs (id, diver_id, name, created_at, '
      "updated_at) VALUES ('al80', 'me', 'AL80', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO cylinder_config_items (id, config_id, tank_role, '
      'volume_l, o2_percent, created_at, updated_at) '
      "VALUES ('ci1', 'al80', 'backGas', 11.1, 32.0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_weight_presets (id, set_id, preset_id, '
      "created_at) VALUES ('wp1', 'warm', 'belt8', 0), "
      "('wp2', 'lead', 'belt8', 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_cylinder_configs (id, set_id, config_id, '
      "created_at) VALUES ('cc1', 'warm', 'al80', 0)",
    );
    engine = RuleEngine(names: (_) async => NameIndex(const []));
  });
  tearDown(tearDownTestDatabase);

  Future<RuleRunResult> addSet(String setId) async {
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Deep',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: [
        DiveMembershipAction(DiveCollection.equipmentSets, MembershipMode.add, [
          setId,
        ]),
      ],
    );
    return engine.run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
      ),
    );
  }

  Set<String> fieldsFor(RuleRunResult result, String diveId) => {
    for (final c in result.changes)
      if (c.targetId == diveId) c.field,
  };

  test('adding a set fills weights and cylinders and records each '
      'change', () async {
    final result = await addSet('warm');

    expect(await weights('d40'), [closeTo(3.63, 1e-9)]);
    expect((await tanks('d40')).single.o2Percent, 32);
    expect(fieldsFor(result, 'd40'), {'equipment', 'weights', 'tanks'});

    // A dive with its own lead keeps it; its tank only gains its size.
    expect(await weights('d45'), [5.0]);
    final t45 = (await tanks('d45')).single;
    expect(t45.o2Percent, 28);
    expect(t45.volume, closeTo(11.1, 1e-9));
    expect(fieldsFor(result, 'd45'), {'equipment', 'tanks'});
  });

  test('a set with only weights changes the dives that had none', () async {
    final result = await addSet('lead');
    expect(await weights('d40'), [closeTo(3.63, 1e-9)]);
    expect(await gearCount('d40'), 0);
    expect(fieldsFor(result, 'd40'), {'weights'});
    expect(fieldsFor(result, 'd45'), isEmpty);
    expect(result.changedTargetCount, 1);
  });

  test('running the rule again changes nothing more', () async {
    await addSet('warm');
    final again = await engine.run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
      ),
    );
    expect(again.changes, isEmpty);
    expect(await weights('d40'), hasLength(1));
    expect(await tanks('d40'), hasLength(1));
  });

  test('undo takes back the weights and cylinders and restores the '
      'filled size', () async {
    final result = await addSet('warm');
    final undone = await undo.undo(result.runId!);

    expect(undone.restoredTargets, 2);
    expect(await weights('d40'), isEmpty);
    expect(await tanks('d40'), isEmpty);
    expect(await gearCount('d40'), 0);
    expect(await weights('d45'), [5.0]);
    final t45 = (await tanks('d45')).single;
    expect(t45.id, 't45');
    expect(t45.volume, isNull);
  });

  test('undo leaves weights the diver changed after the run', () async {
    final result = await addSet('lead');
    await db.customStatement(
      "UPDATE dive_weights SET amount_kg = 6.0 WHERE dive_id = 'd40'",
    );
    final undone = await undo.undo(result.runId!);
    expect(undone.restoredTargets, 0);
    expect(await weights('d40'), [6.0]);
  });
}
