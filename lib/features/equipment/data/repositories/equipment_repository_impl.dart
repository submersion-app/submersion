import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

class EquipmentRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(EquipmentRepository);

  /// Get all active equipment
  Future<List<EquipmentItem>> getActiveEquipment({String? diverId}) async {
    try {
      final query = _db.select(_db.equipment)
        ..where((t) => t.isActive.equals(true))
        ..orderBy([
          (t) => OrderingTerm.asc(t.type),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get active equipment',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all retired equipment
  Future<List<EquipmentItem>> getRetiredEquipment({String? diverId}) async {
    try {
      final query = _db.select(_db.equipment)
        ..where((t) => t.isActive.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get retired equipment',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Emits whenever the `equipment` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchEquipmentChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.equipment));

  /// Get all equipment
  Future<List<EquipmentItem>> getAllEquipment({String? diverId}) async {
    try {
      final query = _db.select(_db.equipment)
        ..orderBy([
          (t) => OrderingTerm.asc(t.type),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all equipment',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get equipment by status
  Future<List<EquipmentItem>> getEquipmentByStatus(
    EquipmentStatus status, {
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.equipment)
        ..where((t) => t.status.equals(status.name))
        ..orderBy([
          (t) => OrderingTerm.asc(t.type),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment by status: ${status.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get equipment by ID
  Future<EquipmentItem?> getEquipmentById(String id) async {
    try {
      final query = _db.select(_db.equipment)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      if (row == null) return null;
      return _mapRowToEquipment(
        row,
        attributes: await getAttributesForEquipment(id),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get multiple equipment items by IDs
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      final query = _db.select(_db.equipment)..where((t) => t.id.isIn(ids));

      final rows = await query.get();
      return _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment by ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create new equipment
  Future<EquipmentItem> createEquipment(EquipmentItem equipment) async {
    try {
      _log.info('Creating equipment: ${equipment.name}');
      final id = equipment.id.isEmpty ? _uuid.v4() : equipment.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.equipment)
          .insert(
            EquipmentCompanion(
              id: Value(id),
              diverId: Value(equipment.diverId),
              name: Value(equipment.name),
              type: Value(equipment.type.name),
              brand: Value(equipment.brand),
              model: Value(equipment.model),
              serialNumber: Value(equipment.serialNumber),
              status: Value(equipment.status.name),
              purchaseDate: Value(
                equipment.purchaseDate?.millisecondsSinceEpoch,
              ),
              purchasePrice: Value(equipment.purchasePrice),
              purchaseCurrency: Value(equipment.purchaseCurrency),
              lastServiceDate: Value(
                equipment.lastServiceDate?.millisecondsSinceEpoch,
              ),
              serviceIntervalDays: Value(equipment.serviceIntervalDays),
              notes: Value(equipment.notes),
              isActive: Value(equipment.isActive),
              customReminderEnabled: Value(equipment.customReminderEnabled),
              customReminderDays: Value(
                equipment.customReminderDays != null
                    ? jsonEncode(equipment.customReminderDays)
                    : null,
              ),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await saveAttributes(id, equipment.attributes);

      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      // Seed service clocks for kinds flagged auto-attach (hydro/VIP for
      // tanks, reg service for regulators, ...). Best-effort: the equipment
      // row is already committed and marked pending above, so a failure here
      // must not rethrow and make the caller treat the whole create as failed
      // (which could prompt a retry and duplicate the item). The clocks can be
      // added manually later; log and continue.
      try {
        await ServiceScheduleRepository().autoAttachForEquipment(
          equipmentId: id,
          type: equipment.type,
          diverId: equipment.diverId,
        );
      } catch (e, stackTrace) {
        _log.error(
          'Auto-attach of default service clocks failed for equipment $id; '
          'the equipment was still created',
          error: e,
          stackTrace: stackTrace,
        );
      }

      _log.info('Created equipment with id: $id');
      return equipment.copyWith(
        id: id,
        attributes: await getAttributesForEquipment(id),
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create equipment: ${equipment.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update equipment
  Future<void> updateEquipment(EquipmentItem equipment) async {
    try {
      _log.info('Updating equipment: ${equipment.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.equipment,
      )..where((t) => t.id.equals(equipment.id))).write(
        EquipmentCompanion(
          name: Value(equipment.name),
          type: Value(equipment.type.name),
          brand: Value(equipment.brand),
          model: Value(equipment.model),
          serialNumber: Value(equipment.serialNumber),
          status: Value(equipment.status.name),
          purchaseDate: Value(equipment.purchaseDate?.millisecondsSinceEpoch),
          purchasePrice: Value(equipment.purchasePrice),
          purchaseCurrency: Value(equipment.purchaseCurrency),
          lastServiceDate: Value(
            equipment.lastServiceDate?.millisecondsSinceEpoch,
          ),
          serviceIntervalDays: Value(equipment.serviceIntervalDays),
          notes: Value(equipment.notes),
          isActive: Value(equipment.isActive),
          customReminderEnabled: Value(equipment.customReminderEnabled),
          customReminderDays: Value(
            equipment.customReminderDays != null
                ? jsonEncode(equipment.customReminderDays)
                : null,
          ),
          updatedAt: Value(now),
        ),
      );
      await saveAttributes(equipment.id, equipment.attributes);
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: equipment.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated equipment: ${equipment.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update equipment: ${equipment.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete equipment. Service schedules and service records are first-class
  /// synced children cascade-deleted by SQLite, but cascades emit no
  /// deletion-log entries, so each is tombstoned explicitly (mirrors
  /// EquipmentSetRepository.deleteSet).
  Future<void> deleteEquipment(String id) async {
    try {
      _log.info('Deleting equipment: $id');
      await _db.transaction(() async {
        final schedules = await (_db.select(
          _db.serviceSchedules,
        )..where((t) => t.equipmentId.equals(id))).get();
        final records = await (_db.select(
          _db.serviceRecords,
        )..where((t) => t.equipmentId.equals(id))).get();
        await (_db.delete(_db.equipment)..where((t) => t.id.equals(id))).go();
        for (final s in schedules) {
          await _syncRepository.logDeletion(
            entityType: 'serviceSchedules',
            recordId: s.id,
          );
        }
        for (final r in records) {
          await _syncRepository.logDeletion(
            entityType: 'serviceRecords',
            recordId: r.id,
          );
        }
        await _syncRepository.logDeletion(
          entityType: 'equipment',
          recordId: id,
        );
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted equipment: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete equipment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark equipment as serviced
  Future<void> markAsServiced(String id) async {
    try {
      final now = DateTime.now();
      await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
        EquipmentCompanion(
          lastServiceDate: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark equipment as serviced: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Retire equipment
  Future<void> retireEquipment(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
        EquipmentCompanion(isActive: const Value(false), updatedAt: Value(now)),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to retire equipment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Reactivate equipment
  Future<void> reactivateEquipment(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
        EquipmentCompanion(isActive: const Value(true), updatedAt: Value(now)),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to reactivate equipment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get equipment with service due
  Future<List<EquipmentItem>> getEquipmentWithServiceDue({
    String? diverId,
  }) async {
    final allEquipment = await getActiveEquipment(diverId: diverId);
    return allEquipment.where((g) => g.isServiceDue).toList();
  }

  /// Get all active equipment with service due dates for notification scheduling
  Future<List<EquipmentItem>> getEquipmentWithServiceDates({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.equipment)
        ..where((t) => t.isActive.equals(true))
        ..where((t) => t.lastServiceDate.isNotNull())
        ..where((t) => t.serviceIntervalDays.isNotNull());

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment with service dates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search equipment by name, brand, model, or serial number
  Future<List<EquipmentItem>> searchEquipment(
    String query, {
    String? diverId,
  }) async {
    try {
      final searchTerm = '%${query.toLowerCase()}%';
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final variables = [
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        if (diverId != null) Variable.withString(diverId),
      ];

      final results = await _db.customSelect('''
        SELECT * FROM equipment
        WHERE (LOWER(name) LIKE ?
           OR LOWER(brand) LIKE ?
           OR LOWER(model) LIKE ?
           OR LOWER(serial_number) LIKE ?)
        $diverFilter
        ORDER BY is_active DESC, type ASC, name ASC
      ''', variables: variables).get();

      final items = results.map((row) {
        return EquipmentItem(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          type: EquipmentType.values.firstWhere(
            (t) => t.name == row.data['type'],
            orElse: () => EquipmentType.other,
          ),
          brand: row.data['brand'] as String?,
          model: row.data['model'] as String?,
          serialNumber: row.data['serial_number'] as String?,
          status: EquipmentStatus.values.firstWhere(
            (s) => s.name == (row.data['status'] as String? ?? 'active'),
            orElse: () => EquipmentStatus.active,
          ),
          purchaseDate: row.data['purchase_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  row.data['purchase_date'] as int,
                )
              : null,
          purchasePrice: (row.data['purchase_price'] as num?)?.toDouble(),
          purchaseCurrency: (row.data['purchase_currency'] as String?) ?? 'USD',
          lastServiceDate: row.data['last_service_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  row.data['last_service_date'] as int,
                )
              : null,
          serviceIntervalDays: row.data['service_interval_days'] as int?,
          notes: (row.data['notes'] as String?) ?? '',
          isActive: row.data['is_active'] == 1,
          customReminderEnabled: row.data['custom_reminder_enabled'] == 1
              ? true
              : row.data['custom_reminder_enabled'] == 0
              ? false
              : null,
          customReminderDays: row.data['custom_reminder_days'] != null
              ? (jsonDecode(row.data['custom_reminder_days'] as String)
                        as List<dynamic>)
                    .cast<int>()
              : null,
        );
      }).toList();
      final attrsById = await getAttributesForEquipmentIds(
        items.map((i) => i.id).toList(),
      );
      return items
          .map((i) => i.copyWith(attributes: attrsById[i.id] ?? const []))
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to search equipment: $query',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dive count for equipment item
  Future<int> getDiveCountForEquipment(String equipmentId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(*) as count
        FROM dive_equipment
        WHERE equipment_id = ?
      ''',
            variables: [Variable.withString(equipmentId)],
          )
          .getSingle();

      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive count for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// (date, duration) samples of dives linked to this equipment via the
  /// dive_equipment junction or dive_tanks.equipment_id, for usage-based
  /// service clocks. Duration is COALESCE(runtime, bottom_time) seconds.
  Future<List<DiveUsageSample>> getUsageSamplesForEquipment(
    String equipmentId, {
    DateTime? since,
  }) async {
    try {
      final rows = await _db
          .customSelect(
            '''
        SELECT d.dive_date_time AS date_ms,
               COALESCE(d.runtime, d.bottom_time, 0) AS duration_sec
        FROM (
          SELECT dive_id FROM dive_equipment WHERE equipment_id = ?1
          UNION
          SELECT dive_id FROM dive_tanks
            WHERE equipment_id = ?1 AND dive_id IS NOT NULL
        ) je
        JOIN dives d ON d.id = je.dive_id
        WHERE (?2 IS NULL OR d.dive_date_time >= ?2)
        ORDER BY d.dive_date_time
      ''',
            variables: [
              Variable.withString(equipmentId),
              Variable(since?.millisecondsSinceEpoch),
            ],
          )
          .get();
      return rows
          .map(
            (r) => DiveUsageSample(
              // dives.dive_date_time is epoch millis with wall-clock-as-UTC
              // semantics (see dive_filter_sql.dart); decode with isUtc: true
              // like the other dive-date mappers so the engine's
              // date.isAfter(anchor) usage comparison is not shifted by the
              // local offset around day boundaries.
              date: DateTime.fromMillisecondsSinceEpoch(
                r.data['date_ms'] as int,
                isUtc: true,
              ),
              durationSeconds: (r.data['duration_sec'] as num).toInt(),
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get usage samples for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get trip count for equipment item (unique trips from dives using this equipment)
  Future<int> getTripCountForEquipment(String equipmentId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(DISTINCT d.trip_id) as count
        FROM dive_equipment de
        INNER JOIN dives d ON de.dive_id = d.id
        WHERE de.equipment_id = ? AND d.trip_id IS NOT NULL
      ''',
            variables: [Variable.withString(equipmentId)],
          )
          .getSingle();

      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get trip count for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get trip IDs for equipment item
  Future<List<String>> getTripIdsForEquipment(String equipmentId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT DISTINCT d.trip_id
        FROM dive_equipment de
        INNER JOIN dives d ON de.dive_id = d.id
        WHERE de.equipment_id = ? AND d.trip_id IS NOT NULL
        ORDER BY d.dive_date_time DESC
      ''',
            variables: [Variable.withString(equipmentId)],
          )
          .get();

      return result.map((row) => row.data['trip_id'] as String).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get trip IDs for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  EquipmentItem _mapRowToEquipment(
    EquipmentData row, {
    List<EquipmentAttribute> attributes = const [],
  }) {
    return EquipmentItem(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      type: EquipmentType.values.firstWhere(
        (t) => t.name == row.type,
        orElse: () => EquipmentType.other,
      ),
      brand: row.brand,
      model: row.model,
      serialNumber: row.serialNumber,
      status: EquipmentStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => EquipmentStatus.active,
      ),
      purchaseDate: row.purchaseDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.purchaseDate!)
          : null,
      purchasePrice: row.purchasePrice,
      purchaseCurrency: row.purchaseCurrency,
      lastServiceDate: row.lastServiceDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.lastServiceDate!)
          : null,
      serviceIntervalDays: row.serviceIntervalDays,
      notes: row.notes,
      isActive: row.isActive,
      attributes: attributes,
      customReminderEnabled: row.customReminderEnabled,
      customReminderDays: row.customReminderDays != null
          ? (jsonDecode(row.customReminderDays!) as List<dynamic>).cast<int>()
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  /// Maps rows to entities with attributes hydrated in ONE batched query
  /// (list reads must not pay a per-item join).
  Future<List<EquipmentItem>> _mapRowsWithAttributes(
    List<EquipmentData> rows,
  ) async {
    final attrsById = await getAttributesForEquipmentIds(
      rows.map((r) => r.id).toList(),
    );
    return rows
        .map(
          (row) => _mapRowToEquipment(
            row,
            attributes: attrsById[row.id] ?? const [],
          ),
        )
        .toList();
  }

  EquipmentAttribute _mapAttributeRow(EquipmentAttributeRow row) =>
      EquipmentAttribute(
        id: row.id,
        equipmentId: row.equipmentId,
        key: row.attrKey,
        isCustom: row.isCustom,
        valueText: row.valueText,
        valueNum: row.valueNum,
        sortOrder: row.sortOrder,
      );

  Future<List<EquipmentAttribute>> getAttributesForEquipment(
    String equipmentId,
  ) async {
    final rows =
        await (_db.select(_db.equipmentAttributes)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(_mapAttributeRow).toList();
  }

  Future<Map<String, List<EquipmentAttribute>>> getAttributesForEquipmentIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.equipmentAttributes)
              ..where((t) => t.equipmentId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final byEquipment = <String, List<EquipmentAttribute>>{};
    for (final row in rows) {
      byEquipment
          .putIfAbsent(row.equipmentId, () => [])
          .add(_mapAttributeRow(row));
    }
    return byEquipment;
  }

  /// Writes the desired end state of [equipmentId]'s attributes: inserts and
  /// updates changed rows, deletes (with a tombstone) rows no longer present.
  /// Curated ids are normalized to the deterministic form here so callers
  /// building attributes before the equipment id exists still converge.
  Future<void> saveAttributes(
    String equipmentId,
    List<EquipmentAttribute> desired,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final normalized = desired.where((a) => a.hasValue).map((a) {
      if (a.isCustom) {
        return a.copyWith(
          equipmentId: equipmentId,
          id: a.id.isNotEmpty ? a.id : _uuid.v4(),
        );
      }
      return a.copyWith(
        equipmentId: equipmentId,
        id: EquipmentAttribute.curatedId(equipmentId, a.key),
      );
    }).toList();

    final existingRows = await (_db.select(
      _db.equipmentAttributes,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    final existingById = {for (final r in existingRows) r.id: r};
    final desiredIds = normalized.map((a) => a.id).toSet();
    final pendingIds = <String>[];

    await _db.transaction(() async {
      for (final row in existingRows) {
        if (desiredIds.contains(row.id)) continue;
        await (_db.delete(
          _db.equipmentAttributes,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'equipmentAttributes',
          recordId: row.id,
        );
      }

      for (final attr in normalized) {
        final existing = existingById[attr.id];
        final unchanged =
            existing != null &&
            existing.attrKey == attr.key &&
            existing.valueText == attr.valueText &&
            existing.valueNum == attr.valueNum &&
            existing.sortOrder == attr.sortOrder;
        if (unchanged) continue;

        await _db
            .into(_db.equipmentAttributes)
            .insertOnConflictUpdate(
              EquipmentAttributesCompanion(
                id: Value(attr.id),
                equipmentId: Value(equipmentId),
                attrKey: Value(attr.key),
                isCustom: Value(attr.isCustom),
                valueText: Value(attr.valueText),
                valueNum: Value(attr.valueNum),
                sortOrder: Value(attr.sortOrder),
                createdAt: Value(existing?.createdAt ?? now),
                updatedAt: Value(now),
              ),
            );
        pendingIds.add(attr.id);
      }
    });

    for (final id in pendingIds) {
      await _syncRepository.markRecordPending(
        entityType: 'equipmentAttributes',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }
}
