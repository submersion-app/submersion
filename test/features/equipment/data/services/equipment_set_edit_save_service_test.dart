import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';

import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_set_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// Fails the replay on the dives, after the set's own writes.
class _FailingReplay extends Fake implements DiveRepository {
  @override
  Future<List<String>> rewriteSetOnDives(
    String setId,
    List<SetHistoryRewrite> rewrites, {
    required bool alsoLogged,
    bool notify = true,
  }) async => throw StateError('replay failed');
}

/// An equipment set page's sitting is written as one History entry, with
/// the default it demotes and the dives it rewrites, and writes only what
/// it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late EquipmentSetRepository sets;
  late DiveRepository dives;
  late EquipmentSetEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<EquipmentSet> stored([String id = 's1']) async =>
      (await sets.getSetById(id, includeGeofences: true))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({EquipmentSet before, EquipmentSet after})?> save(
    EditSession<EquipmentSet> session, {
    bool alsoLogged = false,
    EquipmentSetEditSaveService? using,
  }) => (using ?? service).save(
    setId: session.stored.id,
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
    alsoLogged: alsoLogged,
  );

  Future<void> revertOnly() async {
    final ops = await operations();
    expect(ops, hasLength(1));
    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(
      await revert.planOperation(ops.single['id']! as String),
    );
  }

  Future<Set<String>> gearOn(String diveId) async => {
    for (final row in await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get())
      row.equipmentId,
  };

  Future<Set<String?>> setsOn(String diveId) async => {
    for (final row in await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get())
      row.viaSetId,
  };

  Future<bool> isDefault(String id) async =>
      (await sets.getSetById(id))!.isDefault;

  EquipmentSetGeofence fence(String id, {double radius = 100}) =>
      EquipmentSetGeofence(
        id: id,
        setId: 's1',
        label: 'Here',
        latitude: 10,
        longitude: 20,
        radiusMeters: radius,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseService.instance.database;
    addTearDown(SyncCoordinator.reset);
    sets = EquipmentSetRepository();
    dives = DiveRepository();
    service = EquipmentSetEditSaveService(sets, dives);
    final t = DateTime(2026).millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final id in ['e1', 'e2', 'e3', 'e4']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
    EquipmentSet set(
      String id,
      List<String> members, {
      List<String> includes = const [],
    }) => EquipmentSet(
      id: id,
      diverId: 'd1',
      name: id,
      equipmentIds: members,
      includedSetIds: includes,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await sets.createSet(set('s0', const ['e3']));
    await sets.createSet(set('s1', const ['e1', 'e2']));
    await sets.createSet(set('s2', const []));
    await sets.createSet(set('s3', const [], includes: ['s1']));
    await sets.setAsDefault('s2');
    await sets.addGeofence(fence('g1'));
    for (final (id, planned, viaSet) in [
      ('logged', false, 's1'),
      ('planned', true, 's1'),
      ('outer', false, 's3'),
    ]) {
      await dives.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          diverId: 'd1',
          isPlanned: planned,
        ),
      );
      await dives.replaceGearRows(id, [
        for (final e in ['e1', 'e2'])
          GearProvenance(equipmentId: e, viaSetId: viaSet),
      ]);
    }
    // What setup wrote is not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a name change as one History entry', () async {
    final session = EditSession(await stored())
      ..set(setNameField, 'Cold water');

    final result = await save(session);

    expect((await stored()).name, 'Cold water');
    expect(result!.before.name, 's1');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:equipment_sets:s1:header');
  });

  // One case per value the sitting writes: a value changed in storage
  // during the sitting, on a field the diver did not touch, survives Save.
  final census = <String, ({String sql, bool Function(EquipmentSet) kept})>{
    'name': (
      sql: "UPDATE equipment_sets SET name = 'Renamed' WHERE id = 's1'",
      kept: (s) => s.name == 'Renamed',
    ),
    'description': (
      sql: "UPDATE equipment_sets SET description = 'Kelp' WHERE id = 's1'",
      kept: (s) => s.description == 'Kelp',
    ),
    'auto-apply': (
      sql:
          'UPDATE equipment_sets SET auto_apply_on_computer_import = 1 '
          "WHERE id = 's1'",
      kept: (s) => s.autoApplyOnComputerImport,
    ),
    'show figure': (
      sql: "UPDATE equipment_sets SET show_figure = 0 WHERE id = 's1'",
      kept: (s) => !s.showFigure,
    ),
    'default': (
      sql: "UPDATE equipment_sets SET is_default = 1 WHERE id = 's1'",
      kept: (s) => s.isDefault,
    ),
    'members': (
      sql:
          'INSERT INTO equipment_set_items (set_id, equipment_id) '
          "VALUES ('s1', 'e4')",
      kept: (s) => s.equipmentIds.contains('e4'),
    ),
    'geofences': (
      sql:
          'INSERT INTO equipment_set_geofences (id, set_id, latitude, '
          'longitude, radius_meters, created_at, updated_at) '
          "VALUES ('g9', 's1', 1, 2, 50, 0, 0)",
      kept: (s) => s.geofences.any((g) => g.id == 'g9'),
    ),
  };
  for (final MapEntry(key: value, value: change) in census.entries) {
    test(
      'a field the sitting did not touch keeps its newer value: $value',
      () async {
        final session = EditSession(await stored());
        // Each change touches a card other than the one changed underneath.
        if (value == 'name' || value == 'description') {
          session.set(setShowFigureField, false);
        } else {
          session.set(setNameField, 'Touched');
        }
        await db.customStatement(change.sql);

        await save(session);

        expect(change.kept(await stored()), isTrue);
      },
    );
  }

  test('the weight presets untouched are kept', () async {
    final preset = await WeightPresetRepository().createPreset(
      diverId: 'd1',
      displayName: 'Belt',
      entries: const [
        (weightType: WeightType.belt, amountKg: 3, notes: '', label: ''),
      ],
    );
    final session = EditSession(await stored())..set(setNameField, 'Touched');
    await sets.updateSet(
      (await stored()).copyWith(weightPresetIds: [preset.id]),
    );

    await save(session);

    expect((await stored()).weightPresetIds, [preset.id]);
  });

  test(
    'default on demotes s2 in the same entry, and reverting restores s2',
    () async {
      final session = EditSession(await stored())..set(setDefaultField, true);

      await save(session);

      expect(await isDefault('s1'), isTrue);
      expect(await isDefault('s2'), isFalse);
      await revertOnly();
      expect(await isDefault('s1'), isFalse);
      expect(await isDefault('s2'), isTrue);
    },
  );

  test('default off leaves no default', () async {
    await sets.setAsDefault('s1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    final session = EditSession(await stored())..set(setDefaultField, false);

    await save(session);

    expect(await isDefault('s1'), isFalse);
    expect(await isDefault('s2'), isFalse);
  });

  test('a member deleted underneath is dropped, not re-inserted', () async {
    final session = EditSession(await stored());
    session.set(setMembersField, membersTicked(session, 'e4', true));
    await db.customStatement("DELETE FROM equipment WHERE id = 'e4'");

    await save(session);

    expect((await stored()).equipmentIds, unorderedEquals(['e1', 'e2']));
  });

  test('a geofence edited, one removed and one added are written', () async {
    await sets.addGeofence(fence('g2'));
    final session = EditSession(await stored());
    session.set(
      setGeofencesField,
      geofencesEdited(session, [fence('g1', radius: 300), fence('g3')]),
    );

    await save(session);

    final fences = (await stored()).geofences;
    expect(fences.map((g) => g.id), unorderedEquals(['g1', 'g3']));
    expect(fences.firstWhere((g) => g.id == 'g1').radiusMeters, 300);
  });

  test('the bundle lists are written as held', () async {
    final session = EditSession(await stored('s3'))
      ..set(setBundleListsField, const SetBundleListValues());

    await save(session);

    expect((await stored('s3')).includedSetIds, isEmpty);
    // s3 no longer carries s1's gear: its logged dive stops naming it.
    expect(await setsOn('outer'), {null});
  });

  test('removing e2 rewrites the planned dive and unlinks the logged ones '
      'from s1 and s3', () async {
    final session = EditSession(await stored());
    session.set(setMembersField, membersTicked(session, 'e2', false));

    await save(session);

    expect(await gearOn('planned'), {'e1'});
    expect(await gearOn('logged'), {'e1', 'e2'});
    expect(await setsOn('logged'), {null});
    expect(await gearOn('outer'), {'e1', 'e2'});
    expect(await setsOn('outer'), {null});
  });

  test('with alsoLogged the logged dives of s1 and s3 lose e2 too, in the '
      'entry, and reverting restores them', () async {
    final session = EditSession(await stored());
    session.set(setMembersField, membersTicked(session, 'e2', false));

    await save(session, alsoLogged: true);

    expect(await gearOn('logged'), {'e1'});
    expect(await gearOn('outer'), {'e1'});
    expect(await gearOn('planned'), {'e1'});
    await revertOnly();
    expect(await gearOn('logged'), {'e1', 'e2'});
    expect(await gearOn('outer'), {'e1', 'e2'});
    expect((await stored()).equipmentIds, unorderedEquals(['e1', 'e2']));
  });

  test('a failure in the replay writes nothing, the set included', () async {
    final session = EditSession(await stored())..set(setNameField, 'Renamed');
    session.set(setMembersField, membersTicked(session, 'e2', false));
    session.set(setDefaultField, true);

    await expectLater(
      save(session, using: EquipmentSetEditSaveService(sets, _FailingReplay())),
      throwsStateError,
    );

    final after = await stored();
    expect(after.name, 's1');
    expect(after.equipmentIds, unorderedEquals(['e1', 'e2']));
    expect(await isDefault('s2'), isTrue);
    expect(await gearOn('planned'), {'e1', 'e2'});
    expect(await operations(), isEmpty);
  });

  test('unchanged returns null and writes nothing', () async {
    final result = await save(EditSession(await stored()));

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a set that has gone throws', () async {
    final session = EditSession(await stored())..set(setNameField, 'Gone');
    await sets.deleteSet('s1');

    await expectLater(save(session), throwsStateError);
  });
}
