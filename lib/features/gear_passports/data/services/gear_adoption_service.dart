import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

/// "Add to my gear" for a scanned gear tag (gear tag spec 10): an item of
/// the tag's type with its name, brand, model, serial and passport id, and
/// the tag's last service date as every attached clock's baseline, in one
/// transaction. A held id throws [PassportIdInUse] and nothing is created.
class GearAdoptionService {
  GearAdoptionService({
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
    GearTagPayload tag, {
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
          type: tag.type ?? EquipmentType.other,
          brand: tag.brand,
          model: tag.model,
          serialNumber: tag.serial,
        ),
        notify: false,
      );
      // Unscoped, across the whole library: an item another diver still
      // uses keeps its tag and throws, rolling the new item back; a retired
      // or sold one (gear bought used) gives the id up.
      await _passports.assignPassportId(
        equipmentId: created.id,
        passportId: tag.passportId,
      );
      final last = tag.lastService;
      if (last != null) {
        for (final schedule in await _schedules.getSchedulesForEquipment(
          created.id,
        )) {
          await _schedules.updateSchedule(
            schedule.withBaseline(last, now: at, picked: true),
            notify: false,
          );
        }
      }
      return created;
    });
    SyncEventBus.notifyLocalChange();
    return (await _equipment.getEquipmentById(item.id)) ?? item;
  }
}
