import 'package:submersion/core/constants/enums.dart'
    show TankMaterial, TankRole;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_observation_writes.dart';
import 'package:submersion/features/agent_access/data/writes/families/transmitter_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_key_adoption.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Transmitter keys, through the save the transmitter edit page runs: the
/// key (a serial, or a computer and its channel) behind a transmitter item,
/// then the item's setup on every other key, then the item's serial when it
/// has none. The label follows the item's name. A key can also fill the
/// tanks of past dives it matches, which the app offers after a setup.
class TransmitterWrites extends WritableEntry {
  TransmitterWrites(this._r, {ConditionFindingsRefresh? refreshFindings})
    : _refreshFindings = refreshFindings ?? scheduleConditionFindingsRefresh;

  final RecordRepositories _r;
  final ConditionFindingsRefresh _refreshFindings;

  static const _applyKey = 'apply_to_existing_dives';

  @override
  String get name => 'transmitters';

  @override
  String get table => 'transmitters';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'transmitter_equipment_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'transmitter_equipment_id': const FieldCodec.reference('equipment'),
    'transmitter_serial': const FieldCodec.text(
      maxLength: 40,
      nullable: true,
      trim: true,
    ),
    'dive_computer_id': const FieldCodec.reference(
      'dive_computers',
      nullable: true,
    ),
    // 0-based, as a read lists it; the page shows it from 1.
    'channel_index': const FieldCodec.integer(min: 0, max: 63, nullable: true),
    'role': FieldCodec.enumName(TankRole.values),
    'equipment_id': const FieldCodec.reference('equipment', nullable: true),
    'volume_l': const FieldCodec.number(min: 0.1, max: 100, nullable: true),
    'working_pressure_bar': const FieldCodec.number(
      min: 1,
      max: 400,
      nullable: true,
    ),
    'material': FieldCodec.enumName(TankMaterial.values, nullable: true),
    'preset_name': const FieldCodec.text(
      maxLength: 60,
      nullable: true,
      trim: true,
    ),
    _applyKey: const FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  UniqueClaim? uniqueKey(WriteCheck check) => transmitterClaim(check);

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    return await transmitterKeyProblem(check, _r) ??
        await transmitterConflict(check, _r);
  }

  @override
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final itemId = values['transmitter_equipment_id']! as String;
    return transmitterTouched(
      _r,
      itemId,
      await _entry(null, values, diverId),
      applyToDives: values[_applyKey] == true,
    );
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final current = await _r.transmitters.getById(id);
    if (current == null) return const SideEffects();
    return SideEffects(
      touched: await transmitterTouched(
        _r,
        current.transmitterEquipmentId!,
        await _entry(current, update.values, current.diverId),
        applyToDives: update.values[_applyKey] == true,
      ),
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      _save(null, values, diverId);

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.transmitters.getById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Transmitter key $id no longer exists.',
          details: {'id': id},
        ));
    await _save(current, update.values, current.diverId);
  }

  /// The edit page's save, in its order.
  Future<String> _save(
    Transmitter? current,
    Map<String, Object?> values,
    String? diverId,
  ) async {
    final entry = await _entry(current, values, diverId);
    final repo = _r.transmitters;
    final saved = await saveTransmitterKey(
      entry,
      isNew: current == null,
      repository: repo,
    );
    final itemId = saved.transmitterEquipmentId!;
    await repo.saveSetup(
      itemId,
      role: saved.role,
      cylinderId: saved.equipmentId,
      volumeL: saved.volumeL,
      workingPressureBar: saved.workingPressureBar,
      material: saved.material,
      presetName: saved.presetName,
      exceptKeyId: saved.id,
    );
    final serial = normalizeTransmitterSerial(saved.transmitterSerial);
    final item = await _r.equipment.getEquipmentById(itemId);
    if (serial != null &&
        item != null &&
        normalizeTransmitterSerial(item.serialNumber) == null) {
      await _r.equipment.updateEquipment(item.copyWith(serialNumber: serial));
    }
    if (values[_applyKey] == true) {
      for (final key in await repo.getForEquipment(itemId)) {
        await repo.applyToExistingDives(key);
      }
    }
    return saved.id;
  }

  /// The key [values] make of [current] (or a new one), as the page builds
  /// it: labelled with the item's name and marked configured.
  Future<Transmitter> _entry(
    Transmitter? current,
    Map<String, Object?> values,
    String? diverId,
  ) async {
    T? kept<T>(String key, T? held) =>
        values.containsKey(key) ? values[key] as T? : held;
    final itemId = kept(
      'transmitter_equipment_id',
      current?.transmitterEquipmentId,
    )!;
    final item = await _r.equipment.getEquipmentById(itemId);
    final now = DateTime.now();
    final role = values['role'] as String?;
    final material = kept('material', current?.material?.name);
    return Transmitter(
      id: current?.id ?? '',
      diverId: current?.diverId ?? diverId,
      transmitterSerial: kept('transmitter_serial', current?.transmitterSerial),
      diveComputerId: kept('dive_computer_id', current?.diveComputerId),
      channelIndex: kept('channel_index', current?.channelIndex),
      label: item?.name ?? current?.label ?? '',
      role: role == null
          ? current?.role ?? TankRole.backGas
          : TankRole.values.byName(role),
      volumeL: kept<num>('volume_l', current?.volumeL)?.toDouble(),
      workingPressureBar: kept<num>(
        'working_pressure_bar',
        current?.workingPressureBar,
      )?.toDouble(),
      material: material == null ? null : TankMaterial.values.byName(material),
      presetName: kept('preset_name', current?.presetName),
      equipmentId: kept('equipment_id', current?.equipmentId),
      transmitterEquipmentId: itemId,
      isConfigured: true,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.transmitters.delete(id);

  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    final items = <String>{
      for (final c in changes)
        if (c.parentId case final id? when run.once(('findings', id))) id,
    };
    if (items.isNotEmpty) _refreshFindings(items);
  }
}
