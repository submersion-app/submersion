import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderConfigRepository repository;
  final now = DateTime.utc(2026, 8, 5);

  setUp(() async {
    db = await setUpTestDatabase();
    // Drift's in-memory default leaves foreign keys OFF; without this the
    // demote-on-unit-delete test would pass whether or not the FK is wired.
    await db.customStatement('PRAGMA foreign_keys = ON');
    repository = CylinderConfigRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<void> seedUnit(String id, String name) async {
    final ts = now.millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('$id', '$name', 'rebreather', $ts, $ts)",
    );
  }

  Future<void> seedDiver(String id) async {
    final ts = now.millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$id', 'Test diver', $ts, $ts)",
    );
  }

  domain.CylinderConfigItem item({
    required String id,
    required String configId,
    TankRole role = TankRole.bailout,
    int order = 0,
    double o2 = 21,
    double he = 0,
    double? volume,
    double? pressure,
    TankMaterial? material,
    String? label,
  }) => domain.CylinderConfigItem(
    id: id,
    configId: configId,
    sortOrder: order,
    tankRole: role,
    o2Percent: o2,
    hePercent: he,
    volumeL: volume,
    workingPressureBar: pressure,
    tankMaterial: material,
    label: label,
    createdAt: now,
    updatedAt: now,
  );

  test('creates a config and reads it back', () async {
    await seedDiver('d1');
    final id = await repository.createConfig(
      diverId: 'd1',
      name: 'JJ trimix',
      description: 'Bottom 18/45',
    );

    final loaded = await repository.getConfigById(id);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'JJ trimix');
    expect(loaded.description, 'Bottom 18/45');
    expect(loaded.diverId, 'd1');
    expect(loaded.equipmentId, isNull);
    expect(loaded.isOwnedByUnit, isFalse);
    expect(loaded.items, isEmpty);
  });

  test("getConfigsForEquipment returns only that unit's configs", () async {
    await seedUnit('rb-1', 'JJ');
    await seedUnit('rb-2', 'rEvo');

    await repository.createConfig(equipmentId: 'rb-1', name: 'A');
    await repository.createConfig(equipmentId: 'rb-1', name: 'B');
    await repository.createConfig(equipmentId: 'rb-2', name: 'C');
    await repository.createConfig(name: 'Generic');

    final forUnit = await repository.getConfigsForEquipment('rb-1');
    expect(forUnit.map((c) => c.name).toSet(), {'A', 'B'});
  });

  test(
    'getAllConfigs with includeItems hydrates items in sort order',
    () async {
      final id = await repository.createConfig(name: 'Doubles + 50');
      // saveItems renumbers sortOrder from LIST POSITION, so the caller orders
      // by moving entries rather than maintaining indices. The deliberately
      // wrong `order:` values below are ignored.
      await repository.saveItems(id, [
        item(id: 'i1', configId: id, role: TankRole.backGas, order: 99),
        item(id: 'i2', configId: id, role: TankRole.deco, order: 99, o2: 50),
      ]);

      final configs = await repository.getAllConfigs(includeItems: true);
      final config = configs.single;
      expect(config.items.map((i) => i.tankRole), [
        TankRole.backGas,
        TankRole.deco,
      ]);
      expect(config.items.map((i) => i.sortOrder), [0, 1]);
      expect(config.items.last.o2Percent, 50);
      expect(config.cylinderCount, 2);
    },
  );

  test('item spec fields round-trip, including the material enum', () async {
    final id = await repository.createConfig(name: 'Bailout');
    await repository.saveItems(id, [
      item(
        id: 'i1',
        configId: id,
        role: TankRole.bailout,
        volume: 11.1,
        pressure: 207,
        material: TankMaterial.aluminum,
        label: 'Bailout 1',
        o2: 32,
        he: 0,
      ),
    ]);

    final loaded = await repository.getConfigById(id);
    final only = loaded!.items.single;
    expect(only.volumeL, 11.1);
    expect(only.workingPressureBar, 207);
    expect(only.tankMaterial, TankMaterial.aluminum);
    expect(only.label, 'Bailout 1');
    expect(only.o2Percent, 32);
    expect(only.tankRole, TankRole.bailout);
  });

  test('saveItems replaces the item set and renumbers sort_order', () async {
    final id = await repository.createConfig(name: 'Config');
    await repository.saveItems(id, [
      item(id: 'i1', configId: id, order: 0),
      item(id: 'i2', configId: id, order: 1),
      item(id: 'i3', configId: id, order: 2),
    ]);

    // Drop the middle item; survivors renumber from list position, not from
    // whatever sortOrder the caller happened to pass.
    await repository.saveItems(id, [
      item(id: 'i3', configId: id, order: 99),
      item(id: 'i1', configId: id, order: 99),
    ]);

    final config = await repository.getConfigById(id);
    expect(config!.items.map((i) => i.id), ['i3', 'i1']);
    expect(config.items.map((i) => i.sortOrder), [0, 1]);
  });

  test('saveItems writes deletion-log tombstones for removed items', () async {
    final id = await repository.createConfig(name: 'Config');
    await repository.saveItems(id, [
      item(id: 'i1', configId: id, order: 0),
      item(id: 'i2', configId: id, order: 1),
    ]);

    await repository.saveItems(id, [item(id: 'i1', configId: id, order: 0)]);

    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'cylinderConfigItems'",
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      contains('i2'),
      reason: 'without a tombstone the row resurrects on the next sync pull',
    );
  });

  test('deleteConfig removes its items and tombstones both levels', () async {
    final id = await repository.createConfig(name: 'Config');
    await repository.saveItems(id, [item(id: 'i1', configId: id)]);

    await repository.deleteConfig(id);

    expect(await repository.getConfigById(id), isNull);
    final rows = await db
        .customSelect('SELECT id FROM cylinder_config_items')
        .get();
    expect(rows, isEmpty);

    final tombstones = await db
        .customSelect('SELECT entity_type, record_id FROM deletion_log')
        .get();
    final pairs = tombstones
        .map(
          (r) =>
              '${r.read<String>('entity_type')}:${r.read<String>('record_id')}',
        )
        .toSet();
    expect(pairs, contains('cylinderConfigs:$id'));
    expect(pairs, contains('cylinderConfigItems:i1'));
  });

  test('a config for a deleted unit survives as a generic gas plan', () async {
    await seedUnit('rb-1', 'JJ');
    final id = await repository.createConfig(
      equipmentId: 'rb-1',
      name: 'Trimix',
    );

    await db.customStatement("DELETE FROM equipment WHERE id = 'rb-1'");

    final loaded = await repository.getConfigById(id);
    expect(loaded, isNotNull);
    expect(loaded!.equipmentId, isNull);
    expect(loaded.isOwnedByUnit, isFalse);
    expect(loaded.name, 'Trimix');
  });

  test('updateConfig persists renames and unit reassignment', () async {
    await seedUnit('rb-1', 'JJ');
    final id = await repository.createConfig(name: 'Old name');
    final loaded = await repository.getConfigById(id);

    await repository.updateConfig(
      loaded!.copyWith(name: 'New name', equipmentId: 'rb-1'),
    );

    final again = await repository.getConfigById(id);
    expect(again!.name, 'New name');
    expect(again.equipmentId, 'rb-1');
  });

  test('an unknown persisted role degrades instead of throwing', () async {
    final id = await repository.createConfig(name: 'Config');
    final ts = now.millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO cylinder_config_items "
      "(id, config_id, sort_order, tank_role, created_at, updated_at) "
      "VALUES ('i1', '$id', 0, 'notARole', $ts, $ts)",
    );

    final loaded = await repository.getConfigById(id);
    expect(loaded!.items.single.tankRole, TankRole.backGas);
  });
}
