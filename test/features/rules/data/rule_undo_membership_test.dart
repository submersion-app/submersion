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

/// Undoing a membership change (#3513) puts back what the run changed and
/// nothing else: the dive's type order, the gear it already had, every role
/// a buddy held, and never an item deleted since.
void main() {
  late AppDatabase db;
  late RuleEngine engine;
  final undo = RuleUndoService();

  Future<List<String>> strings(String sql) async => [
    for (final r in await db.customSelect(sql).get())
      r.data.values.first! as String,
  ];

  Future<Object?> diveColumn(String col) async =>
      (await db
              .customSelect("SELECT $col AS v FROM dives WHERE id = 'd40'")
              .getSingle())
          .data['v'];

  Future<List<String>> typesInOrder() => strings(
    "SELECT dive_type_id FROM dive_dive_types WHERE dive_id = 'd40' "
    'ORDER BY created_at, id',
  );

  Future<List<String>> gear() => strings(
    "SELECT equipment_id || ':' || COALESCE(via_equipment_id, '-') "
    "FROM dive_equipment WHERE dive_id = 'd40' ORDER BY equipment_id",
  );

  Future<List<String>> rolesOf(String buddyId) => strings(
    "SELECT role_id FROM dive_buddy_roles WHERE dive_id = 'd40' "
    "AND buddy_id = '$buddyId' ORDER BY role_id",
  );

  Future<void> setTypes(List<String> types) async {
    for (var i = 0; i < types.length; i++) {
      await db.customStatement(
        'INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) '
        "VALUES ('d40-$i', 'd40', '${types[i]}', $i)",
      );
    }
    await db.customStatement(
      "UPDATE dives SET dive_type = '${types.first}' WHERE id = 'd40'",
    );
  }

  Future<void> addBuddy(String id, List<String> roles) async {
    await db.customStatement(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) '
      "VALUES ('db-$id', 'd40', '$id', '${roles.first}', 0)",
    );
    for (final role in roles) {
      await db.customStatement(
        'INSERT INTO dive_buddy_roles '
        '(id, dive_id, buddy_id, role_id, created_at) '
        "VALUES ('r-$id-$role', 'd40', '$id', '$role', 0)",
      );
    }
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me']);
    await seedRuleDive(db, 'd40', maxDepth: 40);
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('ann', 'Ann', 0, 0)",
    );
    engine = RuleEngine(names: (_) async => NameIndex(const []));
  });
  tearDown(tearDownTestDatabase);

  Future<String?> runRule(RuleAction action) async {
    await RuleRepository().create(
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Deep',
      triggers: const {RuleTrigger.afterImport},
      condition: depthOver(30),
      actions: [action],
    );
    final result = await engine.run(
      const RuleRunRequest(
        diverId: 'me',
        trigger: RuleRunTrigger.onDemandAll,
        targets: {RuleSubject.dives: null},
      ),
    );
    return result.runId;
  }

  DiveMembershipAction types(MembershipMode mode, String id) =>
      DiveMembershipAction(DiveCollection.diveTypes, mode, [id]);

  group('dive types', () {
    test('undoing the removal of the only type restores just it', () async {
      await setTypes(['training']);
      final run = await runRule(types(MembershipMode.remove, 'training'));
      expect(await typesInOrder(), ['recreational']);

      final result = await undo.undo(run!);

      expect(result.restoredTargets, 1);
      expect(await typesInOrder(), ['training']);
      expect(await diveColumn('dive_type'), 'training');
    });

    test('undo puts a removed representative type back first', () async {
      await setTypes(['training', 'deep']);
      final run = await runRule(types(MembershipMode.remove, 'training'));
      expect(await typesInOrder(), ['deep']);

      await undo.undo(run!);

      expect(await typesInOrder(), ['training', 'deep']);
      expect(await diveColumn('dive_type'), 'training');
    });

    test('removing a type the dive must keep writes nothing', () async {
      await setTypes(['recreational']);

      final run = await runRule(types(MembershipMode.remove, 'recreational'));

      expect(run, isNull);
      expect(
        await strings("SELECT id FROM dive_dive_types WHERE dive_id = 'd40'"),
        ['d40-0'],
      );
      expect(await diveColumn('updated_at'), kRuleTs);
    });

    test('a removed type deleted since is not put back', () async {
      await db.customStatement(
        'INSERT INTO dive_types (id, diver_id, name, created_at, updated_at) '
        "VALUES ('my-cavern', 'me', 'My cavern', 0, 0)",
      );
      await setTypes(['my-cavern', 'deep']);
      final run = await runRule(types(MembershipMode.remove, 'my-cavern'));
      await db.customStatement("DELETE FROM dive_types WHERE id = 'my-cavern'");

      final result = await undo.undo(run!);

      expect(await typesInOrder(), ['deep']);
      expect(result.restoredTargets, 0);
      expect(result.skippedEditedTargets, 1);
    });
  });

  group('equipment', () {
    test('undoing an added assembly keeps a part the dive had', () async {
      await db.customStatement(
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "VALUES ('reg', 'Regulator', 'regulator', 0, 0), "
        "('first', 'First stage', 'regulator', 0, 0), "
        "('second', 'Second stage', 'regulator', 0, 0), "
        "('mask', 'Mask', 'mask', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO equipment_components (id, parent_equipment_id, '
        'component_equipment_id, created_at, updated_at) '
        "VALUES ('c1', 'reg', 'first', 0, 0), ('c2', 'reg', 'second', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO dive_equipment (dive_id, equipment_id) '
        "VALUES ('d40', 'first'), ('d40', 'mask')",
      );
      final run = await runRule(
        const DiveMembershipAction(
          DiveCollection.equipment,
          MembershipMode.add,
          ['reg'],
        ),
      );
      expect(await gear(), ['first:reg', 'mask:-', 'reg:-', 'second:reg']);

      final result = await undo.undo(run!);

      expect(result.restoredTargets, 1);
      expect(await gear(), ['first:-', 'mask:-']);
    });
  });

  group('courses', () {
    test('a course held only in the dive\'s own column survives', () async {
      await db.customStatement(
        'INSERT INTO courses (id, diver_id, name, agency, start_date, '
        "created_at, updated_at) VALUES ('aow', 'me', 'AOW', 'padi', 0, 0, 0), "
        "('nitrox', 'me', 'Nitrox', 'padi', 0, 0, 0)",
      );
      // A dive split from another keeps its course column, with no course
      // rows until the next open or sync seeds them.
      await db.customStatement(
        "UPDATE dives SET course_id = 'aow' WHERE id = 'd40'",
      );
      final run = await runRule(
        const DiveMembershipAction(DiveCollection.courses, MembershipMode.add, [
          'nitrox',
        ]),
      );

      await undo.undo(run!);

      expect(await diveColumn('course_id'), 'aow');
    });
  });

  group('buddies', () {
    test('undoing a removal restores every role the buddy held', () async {
      await addBuddy('ann', ['instructor', 'student']);
      final run = await runRule(
        const DiveMembershipAction(
          DiveCollection.buddies,
          MembershipMode.remove,
          ['ann'],
        ),
      );
      expect(await rolesOf('ann'), isEmpty);

      await undo.undo(run!);

      expect(await rolesOf('ann'), ['instructor', 'student']);
    });

    test('a buddy given another role since is left on the dive', () async {
      final run = await runRule(
        const DiveMembershipAction(DiveCollection.buddies, MembershipMode.add, [
          'ann',
        ], buddyRoleId: 'instructor'),
      );
      // The diver also ticks Student; the primary role stays.
      await db.customStatement(
        'INSERT INTO dive_buddy_roles '
        '(id, dive_id, buddy_id, role_id, created_at) '
        "VALUES ('later', 'd40', 'ann', 'student', 0)",
      );

      final result = await undo.undo(run!);

      expect(await rolesOf('ann'), ['instructor', 'student']);
      expect(result.restoredTargets, 0);
      expect(result.skippedEditedTargets, 1);
    });

    test('a removed buddy deleted since is not counted restored', () async {
      await addBuddy('ann', ['buddy']);
      final run = await runRule(
        const DiveMembershipAction(
          DiveCollection.buddies,
          MembershipMode.remove,
          ['ann'],
        ),
      );
      await db.customStatement("DELETE FROM buddies WHERE id = 'ann'");

      final result = await undo.undo(run!);

      expect(result.restoredTargets, 0);
      expect(result.skippedEditedTargets, 1);
      expect(
        await strings(
          "SELECT buddy_id FROM dive_buddies WHERE dive_id = 'd40'",
        ),
        isEmpty,
      );
    });
  });
}
