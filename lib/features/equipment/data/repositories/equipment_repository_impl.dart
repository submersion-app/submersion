import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

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
      return rows.map(_mapRowToEquipment).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get active equipment', e, stackTrace);
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
      return rows.map(_mapRowToEquipment).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get retired equipment', e, stackTrace);
      rethrow;
    }
  }

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
      return rows.map(_mapRowToEquipment).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all equipment', e, stackTrace);
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
      return rows.map(_mapRowToEquipment).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment by status: ${status.name}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get equipment by ID
  Future<EquipmentItem?> getEquipmentById(String id) async {
    try {
      final query = _db.select(_db.equipment)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToEquipment(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get equipment by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get multiple equipment items by IDs
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      final query = _db.select(_db.equipment)..where((t) => t.id.isIn(ids));

      final rows = await query.get();
      return rows.map(_mapRowToEquipment).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get equipment by ids', e, stackTrace);
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
              size: Value(equipment.size),
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

      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created equipment with id: $id');
      return equipment.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create equipment: ${equipment.name}',
        e,
        stackTrace,
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
          size: Value(equipment.size),
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
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: equipment.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated equipment: ${equipment.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update equipment: ${equipment.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete equipment
  Future<void> deleteEquipment(String id) async {
    try {
      _log.info('Deleting equipment: $id');
      await (_db.delete(_db.equipment)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'equipment', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted equipment: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete equipment: $id', e, stackTrace);
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
      _log.error('Failed to mark equipment as serviced: $id', e, stackTrace);
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
      _log.error('Failed to retire equipment: $id', e, stackTrace);
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
      _log.error('Failed to reactivate equipment: $id', e, stackTrace);
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
      return rows.map(_mapRowToEquipment).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get equipment with service dates', e, stackTrace);
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

      return results.map((row) {
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
          size: row.data['size'] as String?,
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
    } catch (e, stackTrace) {
      _log.error('Failed to search equipment: $query', e, stackTrace);
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
        e,
        stackTrace,
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
        e,
        stackTrace,
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
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  EquipmentItem _mapRowToEquipment(EquipmentData row) {
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
      size: row.size,
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
      customReminderEnabled: row.customReminderEnabled,
      customReminderDays: row.customReminderDays != null
          ? (jsonDecode(row.customReminderDays!) as List<dynamic>).cast<int>()
          : null,
    );
  }
}
