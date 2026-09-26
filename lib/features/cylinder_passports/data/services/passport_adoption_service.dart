import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_attribute_keys.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// "Add to my gear" for a scanned tag (spec section 9): a tank row with the
/// tag's spec, the tag's passport id, and clock baselines from its dates,
/// all in one transaction. If the id turns out to be held by a cylinder in
/// service, [CylinderPassportRepository.assignPassportId] throws and the
/// whole adoption rolls back, so no half-made tank is left behind.
class PassportAdoptionService {
  PassportAdoptionService({
    EquipmentRepository? equipment,
    CylinderPassportRepository? passports,
    ServiceScheduleRepository? schedules,
  }) : _equipment = equipment ?? EquipmentRepository(),
       _passports = passports ?? CylinderPassportRepository(),
       _schedules = schedules ?? ServiceScheduleRepository();

  final EquipmentRepository _equipment;
  final CylinderPassportRepository _passports;
  final ServiceScheduleRepository _schedules;

  Future<EquipmentItem> adopt(
    CylinderPassportPayload tag, {
    required String? diverId,
    required String fallbackName,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final item = await _equipment.transaction(() async {
      final created = await _equipment.createEquipment(
        EquipmentItem(
          id: '',
          diverId: diverId,
          name: tag.name ?? fallbackName,
          type: EquipmentType.tank,
          serialNumber: tag.serial,
          attributes: _specAttributes(tag),
        ),
        notify: false,
      );
      await _passports.assignPassportId(
        equipmentId: created.id,
        passportId: tag.passportId,
        diverId: diverId,
      );
      await _applyBaselines(created.id, tag, at);
      return created;
    });
    SyncEventBus.notifyLocalChange();
    return (await _equipment.getEquipmentById(item.id)) ?? item;
  }

  List<EquipmentAttribute> _specAttributes(CylinderPassportPayload tag) => [
    if (tag.volumeL case final v?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: EquipmentAttrKeys.volumeL,
        valueNum: v,
      ),
    if (tag.workingPressureBar case final wp?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: wp.toDouble(),
      ),
    if (tag.material case final m?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: EquipmentAttrKeys.tankMaterial,
        valueText: tankMaterialChoiceKey(m),
      ),
    if (tag.valve case final v?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: 'valve_type',
        valueText: valveChoiceKey(v),
      ),
  ];

  Future<void> _applyBaselines(
    String equipmentId,
    CylinderPassportPayload tag,
    DateTime at,
  ) async {
    for (final schedule in await _schedules.getSchedulesForEquipment(
      equipmentId,
    )) {
      final date = switch (schedule.serviceKindId) {
        'hydro' => tag.lastHydro,
        'vip' => tag.lastVip,
        _ => null,
      };
      if (date == null) continue;
      await _schedules.updateSchedule(
        schedule.withBaseline(date, now: at, picked: true),
      );
    }
    if (tag.o2Clean) {
      final schedule = ServiceSchedule(
        id: 'auto-o2-clean-$equipmentId',
        equipmentId: equipmentId,
        serviceKindId: 'o2-clean',
        createdAt: at,
        updatedAt: at,
      );
      await _schedules.createSchedule(
        tag.writtenOn == null
            ? schedule
            : schedule.withBaseline(tag.writtenOn, now: at, picked: true),
        notify: false,
      );
    }
  }
}
