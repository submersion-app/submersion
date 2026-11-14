import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide EquipmentSet;
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import '../../../../helpers/test_database.dart';

/// The three lists an equipment set carries besides its gear (issue #4525):
/// included sets, weight presets and cylinder configurations.
void main() {
  late AppDatabase db;
  late EquipmentSetRepository repo;
  late String presetA;
  late String presetB;
  late String configA;
  final now = DateTime(2026, 11, 1);

  EquipmentSet set(
    String id, {
    String diverId = 'd1',
    List<String> gear = const [],
    List<String> includes = const [],
    List<String> presets = const [],
    List<String> configs = const [],
  }) => EquipmentSet(
    id: id,
    diverId: diverId,
    name: id,
    equipmentIds: gear,
    includedSetIds: includes,
    weightPresetIds: presets,
    cylinderConfigIds: configs,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentSetRepository();
    final t = now.millisecondsSinceEpoch;
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    final equipment = EquipmentRepository();
    for (final id in ['bp', 'reg', 'cam']) {
      await equipment.createEquipment(
        EquipmentItem(
          id: id,
          diverId: 'd1',
          name: id,
          type: EquipmentType.other,
        ),
        notify: false,
      );
    }
    final presets = WeightPresetRepository();
    presetA = (await presets.createPreset(
      diverId: 'd1',
      displayName: 'A',
      entries: const [
        (weightType: WeightType.belt, amountKg: 2.72, notes: '', label: ''),
      ],
    )).id;
    presetB = (await presets.createPreset(
      diverId: 'd1',
      displayName: 'B',
      entries: const [
        (weightType: WeightType.belt, amountKg: 1, notes: '', label: ''),
      ],
    )).id;
    configA = await CylinderConfigRepository().createConfig(
      diverId: 'd1',
      name: 'AL80',
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> pending(String entity) async {
    final rows = await db
        .customSelect(
          'SELECT record_id FROM sync_records '
          'WHERE entity_type = ? AND sync_status = ?',
          variables: [
            Variable<String>(entity),
            const Variable<String>('pending'),
          ],
        )
        .get();
    return [for (final r in rows) r.read<String>('record_id')];
  }

  test('createSet stores the three lists in order', () async {
    await repo.createSet(set('rig', gear: ['bp']));
    await repo.createSet(
      set(
        'outer',
        gear: ['cam'],
        includes: ['rig'],
        presets: [presetB, presetA],
        configs: [configA],
      ),
    );

    final stored = (await repo.getSetById('outer'))!;
    expect(stored.includedSetIds, ['rig']);
    expect(stored.weightPresetIds, [presetB, presetA]);
    expect(stored.cylinderConfigIds, [configA]);

    final listed = (await repo.getAllSets(
      diverId: 'd1',
    )).firstWhere((s) => s.id == 'outer');
    expect(listed.weightPresetIds, [presetB, presetA]);
    expect(listed.includedSetIds, ['rig']);
  });

  test('new list rows are marked pending for sync', () async {
    await repo.createSet(set('rig'));
    await repo.createSet(
      set('outer', includes: ['rig'], presets: [presetA], configs: [configA]),
    );
    expect(await pending('equipmentSetIncludes'), hasLength(1));
    expect(await pending('equipmentSetWeightPresets'), hasLength(1));
    expect(await pending('equipmentSetCylinderConfigs'), hasLength(1));
  });

  test('updateSet reorders, adds and removes list entries', () async {
    await repo.createSet(set('s', presets: [presetA, presetB]));
    final before = await db.select(db.equipmentSetWeightPresets).get();
    final rowOfA = before.firstWhere((r) => r.presetId == presetA);

    await repo.updateSet(
      set('s', presets: [presetB, presetA], configs: [configA]),
    );
    var stored = (await repo.getSetById('s'))!;
    expect(stored.weightPresetIds, [presetB, presetA]);
    expect(stored.cylinderConfigIds, [configA]);
    // A reorder keeps the row and re-stamps it rather than replacing it.
    final after = await db.select(db.equipmentSetWeightPresets).get();
    expect(after.map((r) => r.id).toSet(), before.map((r) => r.id).toSet());
    expect(after.firstWhere((r) => r.id == rowOfA.id).sortOrder, 1);

    await repo.updateSet(set('s', presets: [presetB]));
    stored = (await repo.getSetById('s'))!;
    expect(stored.weightPresetIds, [presetB]);
    expect(stored.cylinderConfigIds, isEmpty);

    final deletions = await db.select(db.deletionLog).get();
    expect(
      deletions.where((d) => d.entityType == 'equipmentSetWeightPresets'),
      hasLength(1),
    );
    expect(
      deletions.where((d) => d.entityType == 'equipmentSetCylinderConfigs'),
      hasLength(1),
    );
  });

  test('updateSet still returns the own-gear diff only', () async {
    await repo.createSet(set('rig', gear: ['bp']));
    await repo.createSet(set('outer', gear: ['cam']));
    final diff = await repo.updateSet(
      set('outer', gear: ['cam', 'reg'], includes: ['rig']),
    );
    expect(diff.added, ['reg']);
    expect(diff.removed, isEmpty);
  });

  test('items are the effective gear; equipmentIds stays own', () async {
    await repo.createSet(set('rig', gear: ['bp', 'reg']));
    await repo.createSet(set('outer', gear: ['reg', 'cam'], includes: ['rig']));

    final stored = (await repo.getSetById('outer', includeItems: true))!;
    expect(stored.equipmentIds.toSet(), {'reg', 'cam'});
    expect(stored.items!.map((i) => i.id).toSet(), {'bp', 'reg', 'cam'});

    expect((await repo.getEffectiveEquipmentIds('outer')).toSet(), {
      'bp',
      'reg',
      'cam',
    });
    expect(await repo.getEffectiveEquipmentIds('outer'), hasLength(3));
    expect((await repo.getEffectiveEquipmentIds('rig')).toSet(), {'bp', 'reg'});
  });

  test('a list entry whose target is gone is dropped, not fatal', () async {
    await repo.createSet(
      set('s', includes: ['nope'], presets: ['nope', presetA], configs: ['x']),
    );
    final stored = (await repo.getSetById('s'))!;
    expect(stored.includedSetIds, isEmpty);
    expect(stored.weightPresetIds, [presetA]);
    expect(stored.cylinderConfigIds, isEmpty);
  });

  group('nesting rule', () {
    setUp(() async {
      await repo.createSet(set('plain'));
      await repo.createSet(set('other'));
      await repo.createSet(set('outer', includes: ['plain']));
      await repo.createSet(set('foreign', diverId: 'd2'));
    });

    test('a set cannot include itself', () {
      expect(
        () => repo.updateSet(set('other', includes: ['other'])),
        throwsArgumentError,
      );
    });

    test('a set cannot include a set that has includes', () {
      expect(
        () => repo.updateSet(set('other', includes: ['outer'])),
        throwsArgumentError,
      );
      expect(
        () => repo.createSet(set('new', includes: ['outer'])),
        throwsArgumentError,
      );
    });

    test('an included set cannot gain includes', () {
      expect(
        () => repo.updateSet(set('plain', includes: ['other'])),
        throwsArgumentError,
      );
    });

    test('a set cannot include another diver\'s set', () {
      expect(
        () => repo.updateSet(set('other', includes: ['foreign'])),
        throwsArgumentError,
      );
    });

    test('a refused write changes nothing', () async {
      await expectLater(
        repo.updateSet(set('other', includes: ['outer']).copyWith(name: 'X')),
        throwsArgumentError,
      );
      expect((await repo.getSetById('other'))!.name, 'other');
    });
  });

  test('deleting a preset, configuration or included set drops it '
      'from the sets that used it', () async {
    await repo.createSet(set('rig'));
    await repo.createSet(
      set('outer', includes: ['rig'], presets: [presetA], configs: [configA]),
    );
    await WeightPresetRepository().deletePreset(presetA);
    await CylinderConfigRepository().deleteConfig(configA);
    await repo.deleteSet('rig');

    final stored = (await repo.getSetById('outer'))!;
    expect(stored.includedSetIds, isEmpty);
    expect(stored.weightPresetIds, isEmpty);
    expect(stored.cylinderConfigIds, isEmpty);
  });

  test('watchSetChanges ticks when a junction row changes', () async {
    await repo.createSet(set('s'));
    final ticked = Completer<void>();
    final sub = repo.watchSetChanges().listen((_) {
      if (!ticked.isCompleted) ticked.complete();
    });
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    await repo.updateSet(set('s', presets: [presetA]));
    await ticked.future.timeout(const Duration(seconds: 3));
  });
}
