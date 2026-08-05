import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';

/// CRUD for service clocks plus the auto-attach hook that seeds clocks on
/// newly created equipment.
class ServiceScheduleRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  Future<List<domain.ServiceSchedule>> getSchedulesForEquipment(
    String equipmentId,
  ) async {
    final rows = await (_db.select(
      _db.serviceSchedules,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    return rows.map(_mapRow).toList();
  }

  Future<List<domain.ServiceSchedule>> getAllSchedules() async {
    final rows = await _db.select(_db.serviceSchedules).get();
    return rows.map(_mapRow).toList();
  }

  Future<domain.ServiceSchedule> createSchedule(
    domain.ServiceSchedule schedule,
  ) async {
    final id = schedule.id.isEmpty ? _uuid.v4() : schedule.id;
    final now = DateTime.now();
    await _db
        .into(_db.serviceSchedules)
        .insert(
          ServiceSchedulesCompanion(
            id: Value(id),
            equipmentId: Value(schedule.equipmentId),
            serviceKindId: Value(schedule.serviceKindId),
            intervalDays: Value(schedule.intervalDays),
            intervalDives: Value(schedule.intervalDives),
            intervalHours: Value(schedule.intervalHours),
            anchorDate: Value(schedule.anchorDate?.millisecondsSinceEpoch),
            enabled: Value(schedule.enabled),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'serviceSchedules',
      recordId: id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
    return schedule.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  Future<void> updateSchedule(domain.ServiceSchedule schedule) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.serviceSchedules,
    )..where((t) => t.id.equals(schedule.id))).write(
      ServiceSchedulesCompanion(
        intervalDays: Value(schedule.intervalDays),
        intervalDives: Value(schedule.intervalDives),
        intervalHours: Value(schedule.intervalHours),
        anchorDate: Value(schedule.anchorDate?.millisecondsSinceEpoch),
        enabled: Value(schedule.enabled),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'serviceSchedules',
      recordId: schedule.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> deleteSchedule(String id) async {
    await (_db.delete(
      _db.serviceSchedules,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(
      entityType: 'serviceSchedules',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Creates one enabled schedule per auto-attach kind matching [type] that
  /// the item does not already have. Deterministic ids keep this idempotent
  /// and collision-free across devices.
  ///
  /// Kinds are scoped to [diverId]: built-ins and unowned customs always
  /// apply; another diver's custom kinds never auto-attach.
  Future<void> autoAttachForEquipment({
    required String equipmentId,
    required EquipmentType type,
    String? diverId,
  }) async {
    final kinds = await ServiceKindRepository().getAllKinds();
    final existing = await getSchedulesForEquipment(equipmentId);
    final existingKindIds = existing.map((s) => s.serviceKindId).toSet();
    final now = DateTime.now();
    for (final kind in kinds) {
      if (!kind.isBuiltIn && kind.diverId != null && kind.diverId != diverId) {
        continue; // another diver's custom kind
      }
      if (!kind.autoAttach || !kind.appliesTo(type)) continue;
      if (existingKindIds.contains(kind.id)) continue;
      await createSchedule(
        domain.ServiceSchedule(
          id: 'auto-${kind.id}-$equipmentId',
          equipmentId: equipmentId,
          serviceKindId: kind.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  /// The widest configured reminder-days value for [diverId] (default 30):
  /// used as the dueSoon threshold so a clock turns amber as soon as its
  /// earliest reminder would fire. Read straight from diver_settings rather
  /// than the settings notifier to keep clock evaluation free of provider
  /// initialization order.
  Future<int> getDueSoonWindowDays({String? diverId}) async {
    if (diverId == null) return 30;
    final row =
        await (_db.select(_db.diverSettings)
              ..where((t) => t.diverId.equals(diverId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return 30;
    try {
      final days = (jsonDecode(row.serviceReminderDays) as List<dynamic>)
          .cast<int>();
      if (days.isEmpty) return 30;
      return days.reduce((a, b) => a > b ? a : b);
    } catch (_) {
      return 30;
    }
  }

  domain.ServiceSchedule _mapRow(ServiceScheduleRow row) {
    return domain.ServiceSchedule(
      id: row.id,
      equipmentId: row.equipmentId,
      serviceKindId: row.serviceKindId,
      intervalDays: row.intervalDays,
      intervalDives: row.intervalDives,
      intervalHours: row.intervalHours,
      anchorDate: row.anchorDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.anchorDate!),
      enabled: row.enabled,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
