import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/service_kind.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart'
    as domain;

import '../../../helpers/test_database.dart';

/// A table that declares an `hlc` column but is missing from
/// [SyncRepository.hlcTargets] never gets that column stamped: `_stampHlc`
/// silently no-ops for unregistered entity types. Its rows then stay
/// `hlc IS NULL` forever, and the incremental export's `hlc > watermark`
/// filter excludes them (SQL `NULL > x` is not true), so local edits reach
/// peers only on a full base republish. Issue #1144.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------
  // Schema-driven completeness
  // ---------------------------------------------------------------------

  /// Infrastructure tables that carry an `hlc` column without being
  /// conflict-capable entity rows: `deletion_log` stores the clock a
  /// tombstone was stamped with, `sync_metadata` persists this device's
  /// clock. Neither is ever marked pending, so neither belongs in
  /// [SyncRepository.hlcTargets].
  const exempt = {'deletion_log', 'sync_metadata'};

  Set<String> tablesWithHlcColumn() => db.allTables
      .where((t) => t.$columns.any((c) => c.name == 'hlc'))
      .map((t) => t.actualTableName)
      .toSet();

  test('every table with an hlc column is registered in hlcTargets', () {
    final registered = SyncRepository.hlcTargets.values
        .map((t) => t.table)
        .toSet();
    final unregistered = tablesWithHlcColumn()
        .difference(registered)
        .difference(exempt);

    expect(
      unregistered,
      isEmpty,
      reason:
          'These tables declare an hlc column but no entity type stamps it, '
          'so their rows are invisible to every incremental changeset. '
          'Register them in SyncRepository.hlcTargets, or add them to the '
          'documented exempt set if they are not entity rows.',
    );
  });

  test('every hlcTargets entry names a real table with an hlc column', () {
    final withHlc = tablesWithHlcColumn();
    for (final entry in SyncRepository.hlcTargets.entries) {
      expect(
        withHlc,
        contains(entry.value.table),
        reason:
            '${entry.key} is registered against "${entry.value.table}", which '
            'has no hlc column in the live schema.',
      );
    }
  });

  test('every hlcTargets entry names a real primary-key column', () {
    final columnsByTable = {
      for (final t in db.allTables)
        t.actualTableName: t.$columns.map((c) => c.name).toSet(),
    };
    for (final entry in SyncRepository.hlcTargets.entries) {
      expect(
        columnsByTable[entry.value.table],
        contains(entry.value.pk),
        reason:
            '${entry.key} stamps by "${entry.value.pk}", which does not exist '
            'on ${entry.value.table}; the UPDATE would silently match no rows.',
      );
    }
  });

  test('the exempt set only lists tables that really carry an hlc', () {
    expect(
      tablesWithHlcColumn(),
      containsAll(exempt),
      reason: 'a stale exemption would hide a genuinely missing registration',
    );
  });

  // ---------------------------------------------------------------------
  // Write paths (through the repositories, never through upsertRecord --
  // the remote apply path carries the peer's HLC in the payload and would
  // mask a missing registration).
  // ---------------------------------------------------------------------

  Future<String?> hlcOf(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT hlc FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.read<String?>('hlc');
  }

  Future<void> seedEquipment(String id) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Reg',
          type: EquipmentType.regulator.name,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

  test('ServiceKindRepository.createKind stamps an hlc', () async {
    final kind = await ServiceKindRepository().createKind(
      domain.ServiceKind(
        id: 'kind-1',
        name: 'Annual service',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    expect(await hlcOf('service_kinds', kind.id), isNotNull);
  });

  test('ServiceScheduleRepository.createSchedule stamps an hlc', () async {
    await seedEquipment('eq-1');
    final kind = await ServiceKindRepository().createKind(
      domain.ServiceKind(
        id: 'kind-1',
        name: 'Annual service',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    final schedule = await ServiceScheduleRepository().createSchedule(
      domain.ServiceSchedule(
        id: 'sched-1',
        equipmentId: 'eq-1',
        serviceKindId: kind.id,
        intervalDays: 365,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    expect(await hlcOf('service_schedules', schedule.id), isNotNull);
  });

  test('CylinderConfigRepository.createConfig stamps an hlc', () async {
    final id = await CylinderConfigRepository().createConfig(name: 'Trimix');

    expect(await hlcOf('cylinder_configs', id), isNotNull);
  });

  test('CylinderConfigRepository.saveItems stamps an hlc per item', () async {
    final repo = CylinderConfigRepository();
    final configId = await repo.createConfig(name: 'Trimix');

    await repo.saveItems(configId, [
      domain.CylinderConfigItem(
        id: 'item-1',
        configId: configId,
        tankRole: TankRole.backGas,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);

    expect(await hlcOf('cylinder_config_items', 'item-1'), isNotNull);
  });

  test('EquipmentSetRepository.addGeofence stamps an hlc', () async {
    final repo = EquipmentSetRepository();
    final set = await repo.createSet(
      domain.EquipmentSet(
        id: 'set-1',
        name: 'Cold water',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    await repo.addGeofence(
      domain.EquipmentSetGeofence(
        id: 'fence-1',
        setId: set.id,
        latitude: 36.62,
        longitude: -121.9,
        radiusMeters: 24000,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    expect(await hlcOf('equipment_set_geofences', 'fence-1'), isNotNull);
  });

  // ---------------------------------------------------------------------
  // End to end: the stamp is only worth anything if the row then survives
  // the changeset's `hlc > watermark` filter. This is the user-visible half
  // of #1144 -- without it these edits reached peers only on a full base
  // republish.
  // ---------------------------------------------------------------------

  test('locally edited rows land in the incremental changeset', () async {
    final kinds = ServiceKindRepository();
    final schedules = ServiceScheduleRepository();
    final configs = CylinderConfigRepository();
    final sets = EquipmentSetRepository();

    domain.ServiceKind kind(String id) => domain.ServiceKind(
      id: id,
      name: 'Annual service $id',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    domain.EquipmentSetGeofence fence(String id, String setId) =>
        domain.EquipmentSetGeofence(
          id: id,
          setId: setId,
          latitude: 36.62,
          longitude: -121.9,
          radiusMeters: 24000,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
    domain.CylinderConfigItem item(String id, String configId) =>
        domain.CylinderConfigItem(
          id: id,
          configId: configId,
          tankRole: TankRole.backGas,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    await seedEquipment('eq-1');
    final oldSet = await sets.createSet(
      domain.EquipmentSet(
        id: 'set-old',
        name: 'Old',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await kinds.createKind(kind('kind-old'));
    await schedules.createSchedule(
      domain.ServiceSchedule(
        id: 'sched-old',
        equipmentId: 'eq-1',
        serviceKindId: 'kind-old',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final oldConfig = await configs.createConfig(name: 'Old');
    await configs.saveItems(oldConfig, [item('item-old', oldConfig)]);
    await sets.addGeofence(fence('fence-old', oldSet.id));

    // Everything above is already published as far as a peer is concerned.
    final watermark = await SyncRepository().maxRowHlc();
    expect(watermark, isNotNull);

    await kinds.createKind(kind('kind-new'));
    await schedules.createSchedule(
      domain.ServiceSchedule(
        id: 'sched-new',
        equipmentId: 'eq-1',
        serviceKindId: 'kind-old',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final newConfig = await configs.createConfig(name: 'New');
    await configs.saveItems(newConfig, [item('item-new', newConfig)]);
    await sets.addGeofence(fence('fence-new', oldSet.id));

    final changeset = await SyncDataSerializer().exportChangeset(
      deviceId: await SyncRepository().getDeviceId(),
      hlcWatermark: watermark,
      deletions: const [],
    );

    Set<Object?> idsIn(List<Map<String, dynamic>> rows) =>
        rows.map((r) => r['id']).toSet();

    expect(idsIn(changeset.data.serviceKinds), contains('kind-new'));
    expect(idsIn(changeset.data.serviceSchedules), contains('sched-new'));
    expect(idsIn(changeset.data.cylinderConfigs), contains(newConfig));
    expect(idsIn(changeset.data.cylinderConfigItems), contains('item-new'));
    expect(idsIn(changeset.data.equipmentSetGeofences), contains('fence-new'));

    // Rows at or below the watermark must not be re-sent.
    expect(idsIn(changeset.data.serviceKinds), isNot(contains('kind-old')));
    expect(
      idsIn(changeset.data.serviceSchedules),
      isNot(contains('sched-old')),
    );
    expect(idsIn(changeset.data.cylinderConfigs), isNot(contains(oldConfig)));
    expect(
      idsIn(changeset.data.cylinderConfigItems),
      isNot(contains('item-old')),
    );
    expect(
      idsIn(changeset.data.equipmentSetGeofences),
      isNot(contains('fence-old')),
    );
  });
}
