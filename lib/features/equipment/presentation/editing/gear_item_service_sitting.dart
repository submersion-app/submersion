import 'package:uuid/uuid.dart';

import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
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
  write: (item, loaded, current) async {
    final repository = ServiceScheduleRepository();
    final byId = {for (final s in loaded) s.id: s};
    final kept = {for (final s in current) s.id};
    var changed = false;
    for (final schedule in current) {
      final before = byId[schedule.id];
      if (before == null) {
        await repository.createSchedule(schedule, notify: false);
        changed = true;
      } else if (before != schedule) {
        await repository.updateSchedule(schedule, notify: false);
        changed = true;
      }
    }
    for (final schedule in loaded) {
      if (kept.contains(schedule.id)) continue;
      await repository.deleteSchedule(schedule.id);
      changed = true;
    }
    return changed;
  },
);

/// The item's service records held in its page's sitting: added (a Log
/// service on a clock included), edited and deleted there, written at Save.
/// Writing one refreshes the item's last service date, inside the sitting.
final gearItemServiceRecordsList = SittingList<EquipmentItem, ServiceRecord>(
  key: 'equipment.serviceRecords',
  cardId: GearItemCardId.serviceHistory.name,
  read: (item) => ServiceRecordRepository().getRecordsForEquipment(item.id),
  write: (item, loaded, current) async {
    final repository = ServiceRecordRepository();
    final byId = {for (final r in loaded) r.id: r};
    final kept = {for (final r in current) r.id};
    var changed = false;
    for (final record in current) {
      final before = byId[record.id];
      if (before == null) {
        await repository.createRecord(record);
        changed = true;
      } else if (before != record) {
        await repository.updateRecord(record);
        changed = true;
      }
    }
    for (final record in loaded) {
      if (kept.contains(record.id)) continue;
      await repository.deleteRecord(record.id);
      changed = true;
    }
    return changed;
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
