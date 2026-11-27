import 'package:uuid/uuid.dart';

import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_row_writes.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

const _uuid = Uuid();

/// The item's service clocks held in its page's sitting (issue #4527, phase
/// 3, plan 6): added, changed, paused, resumed and removed there, written at
/// Save. Only the difference is written.
final gearItemClocksList = SittingList<EquipmentItem, ServiceSchedule>(
  key: 'equipment.clocks',
  cardId: GearItemCardId.serviceClocks.name,
  read: (item) => ServiceScheduleRepository().getSchedulesForEquipment(item.id),
  write: (item, loaded, current) {
    final repository = ServiceScheduleRepository();
    final read = {for (final s in loaded) s.id};
    Future<Map<String, ServiceSchedule>>? gained;
    // The clocks of the item the list did not read: those Save attached to
    // a new item (plan 11), by kind, read once a clock is added.
    Future<Map<String, ServiceSchedule>> gainedByKind() => gained ??= repository
        .getSchedulesForEquipment(item.id)
        .then(
          (rows) => {
            for (final s in rows)
              if (!read.contains(s.id)) s.serviceKindId: s,
          },
        );
    return writeRowChanges(
      loaded: loaded,
      current: current,
      idOf: (s) => s.id,
      create: (s) async {
        // A kind the item has gained since takes the added clock's
        // settings instead of a second clock, as a clone's clocks do.
        final there = (await gainedByKind())[s.serviceKindId];
        if (there == null) {
          await repository.createSchedule(s, notify: false);
        } else {
          await repository.updateSchedule(
            clockMergedInto(there, s),
            notify: false,
          );
        }
      },
      update: (s) => repository.updateSchedule(s, notify: false),
      delete: repository.deleteSchedule,
    );
  },
);

/// [added] in place of [there], a clock of the same kind already on the
/// item: [added]'s settings under [there]'s id, keeping [there]'s baseline
/// when [added] sets none (one Save took from an inspection date).
ServiceSchedule clockMergedInto(ServiceSchedule there, ServiceSchedule added) {
  final merged = added.copyWith(id: there.id, createdAt: there.createdAt);
  if (added.anchorDate != null) return merged;
  return merged.copyWith(
    anchorDate: there.anchorDate,
    anchorSetAt: there.anchorSetAt,
  );
}

/// The item's service records held in its page's sitting: added (a Log
/// service on a clock included), edited and deleted there, written at Save.
/// Writing one refreshes the item's last service date, inside the sitting.
final gearItemServiceRecordsList = SittingList<EquipmentItem, ServiceRecord>(
  key: 'equipment.serviceRecords',
  cardId: GearItemCardId.serviceHistory.name,
  read: (item) => ServiceRecordRepository().getRecordsForEquipment(item.id),
  write: (item, loaded, current) {
    final repository = ServiceRecordRepository();
    return writeRowChanges(
      loaded: loaded,
      current: current,
      idOf: (r) => r.id,
      create: repository.createRecord,
      update: repository.updateRecord,
      delete: repository.deleteRecord,
    );
  },
);

/// [rows] with [row] put in: a new one (no id yet) gets an id of its own and
/// goes first, as the newest; one already there replaces itself.
List<ServiceRecord> serviceRecordsAfterSave(
  List<ServiceRecord> rows,
  ServiceRecord row,
) {
  if (row.id.isEmpty) return [row.copyWith(id: _uuid.v4()), ...rows];
  return [for (final r in rows) r.id == row.id ? row : r];
}

/// [rows] with the schedule [row] put in: a new one (no id yet) gets an id
/// of its own and goes last; one already there replaces itself.
List<ServiceSchedule> clocksAfterSave(
  List<ServiceSchedule> rows,
  ServiceSchedule row,
) {
  if (row.id.isEmpty) return [...rows, row.copyWith(id: _uuid.v4())];
  final known = rows.any((s) => s.id == row.id);
  return [for (final s in rows) s.id == row.id ? row : s, if (!known) row];
}

/// Puts [row] into the sitting's clocks. Does nothing before they are read.
void holdClock(EditSession<EquipmentItem> session, ServiceSchedule row) {
  final rows = gearItemClocksList.current(session);
  if (rows == null) return;
  gearItemClocksList.set(session, clocksAfterSave(rows, row));
}

/// Takes the clock [id] out of the sitting's clocks.
void removeHeldClock(EditSession<EquipmentItem> session, String id) {
  final rows = gearItemClocksList.current(session);
  if (rows == null) return;
  gearItemClocksList.set(session, [
    for (final s in rows)
      if (s.id != id) s,
  ]);
}

/// Puts [row] into the sitting's service records. Does nothing before they
/// are read.
void holdServiceRecord(EditSession<EquipmentItem> session, ServiceRecord row) {
  final rows = gearItemServiceRecordsList.current(session);
  if (rows == null) return;
  gearItemServiceRecordsList.set(session, serviceRecordsAfterSave(rows, row));
}

/// Takes the service record [id] out of the sitting's records.
void removeHeldServiceRecord(EditSession<EquipmentItem> session, String id) {
  final rows = gearItemServiceRecordsList.current(session);
  if (rows == null) return;
  gearItemServiceRecordsList.set(session, [
    for (final r in rows)
      if (r.id != id) r,
  ]);
}
