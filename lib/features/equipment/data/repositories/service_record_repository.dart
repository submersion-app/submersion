import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart'
    as domain;

class ServiceRecordRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Newest service first, then by kind (no kind first). The index on
  /// (equipment_id, service_kind_id) yields that order on its own, but a
  /// scan does not, and SQLite picks between them from its statistics.
  static final List<OrderClauseGenerator<$ServiceRecordsTable>> _newestFirst = [
    (t) => OrderingTerm.desc(t.serviceDate),
    (t) => OrderingTerm.asc(t.serviceKindId),
  ];

  /// Emits whenever the `service_records` table changes so the service-history
  /// providers can refresh after a sync or any other write that bypasses the
  /// notifiers.
  Stream<void> watchServiceRecordsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.serviceRecords));

  /// Get all service records for an equipment item, newest first.
  ///
  /// Records on the same day are ordered by service kind, no kind first:
  /// without that tie-break their order was the query plan's, which
  /// changes once ANALYZE has run (issue #1867).
  Future<List<domain.ServiceRecord>> getRecordsForEquipment(
    String equipmentId,
  ) async {
    final query = _db.select(_db.serviceRecords)
      ..where((t) => t.equipmentId.equals(equipmentId))
      ..orderBy(_newestFirst);

    final rows = await query.get();
    return rows.map(_mapRowToServiceRecord).toList();
  }

  /// [getRecordsForEquipment] for many items at once, keyed by equipment
  /// id, in the same order within an item; an item without records is
  /// absent. One statement per chunk of ids instead of one per item, for
  /// the exports that walk every item's history (issue #1867).
  Future<Map<String, List<domain.ServiceRecord>>> getRecordsForEquipmentIds(
    List<String> equipmentIds,
  ) async {
    if (equipmentIds.isEmpty) return {};
    final byItem = <String, List<domain.ServiceRecord>>{};
    for (final chunk in seriesIdChunks(equipmentIds)) {
      final rows =
          await (_db.select(_db.serviceRecords)
                ..where((t) => t.equipmentId.isIn(chunk))
                ..orderBy(_newestFirst))
              .get();
      for (final row in rows) {
        byItem
            .putIfAbsent(row.equipmentId, () => [])
            .add(_mapRowToServiceRecord(row));
      }
    }
    return byItem;
  }

  /// Get a single service record by ID
  Future<domain.ServiceRecord?> getRecordById(String id) async {
    final query = _db.select(_db.serviceRecords)..where((t) => t.id.equals(id));

    final row = await query.getSingleOrNull();
    return row != null ? _mapRowToServiceRecord(row) : null;
  }

  /// Get the most recent service record for an equipment item
  Future<domain.ServiceRecord?> getMostRecentRecord(String equipmentId) async {
    final query = _db.select(_db.serviceRecords)
      ..where((t) => t.equipmentId.equals(equipmentId))
      ..orderBy([(t) => OrderingTerm.desc(t.serviceDate)])
      ..limit(1);

    final row = await query.getSingleOrNull();
    return row != null ? _mapRowToServiceRecord(row) : null;
  }

  /// Create a new service record
  Future<domain.ServiceRecord> createRecord(domain.ServiceRecord record) async {
    final id = record.id.isEmpty ? _uuid.v4() : record.id;
    final now = DateTime.now();

    await _db
        .into(_db.serviceRecords)
        .insert(
          ServiceRecordsCompanion(
            id: Value(id),
            equipmentId: Value(record.equipmentId),
            serviceCategory: Value(record.serviceCategory.name),
            serviceKindId: Value(record.serviceKindId),
            serviceDate: Value(record.serviceDate.millisecondsSinceEpoch),
            provider: Value(record.provider),
            cost: Value(record.cost),
            currency: Value(record.currency),
            nextServiceDue: Value(
              record.nextServiceDue?.millisecondsSinceEpoch,
            ),
            notes: Value(record.notes),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );

    await _syncRepository.markRecordPending(
      entityType: 'serviceRecords',
      recordId: id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();

    // Update the equipment's lastServiceDate
    await _updateEquipmentLastServiceDate(
      record.equipmentId,
      record.serviceDate,
    );

    return record.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  /// Update an existing service record
  Future<void> updateRecord(domain.ServiceRecord record) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(
      _db.serviceRecords,
    )..where((t) => t.id.equals(record.id))).write(
      ServiceRecordsCompanion(
        serviceCategory: Value(record.serviceCategory.name),
        serviceKindId: Value(record.serviceKindId),
        serviceDate: Value(record.serviceDate.millisecondsSinceEpoch),
        provider: Value(record.provider),
        cost: Value(record.cost),
        currency: Value(record.currency),
        nextServiceDue: Value(record.nextServiceDue?.millisecondsSinceEpoch),
        notes: Value(record.notes),
        updatedAt: Value(now),
      ),
    );

    await _syncRepository.markRecordPending(
      entityType: 'serviceRecords',
      recordId: record.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();

    // Update equipment's lastServiceDate if this is the most recent record
    final mostRecent = await getMostRecentRecord(record.equipmentId);
    if (mostRecent != null) {
      await _updateEquipmentLastServiceDate(
        record.equipmentId,
        mostRecent.serviceDate,
      );
    }
  }

  /// Delete a service record
  Future<void> deleteRecord(String id) async {
    // Get record before deleting to update equipment
    final record = await getRecordById(id);

    await (_db.delete(_db.serviceRecords)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(
      entityType: 'serviceRecords',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();

    // Update equipment's lastServiceDate if needed
    if (record != null) {
      final mostRecent = await getMostRecentRecord(record.equipmentId);
      if (mostRecent != null) {
        await _updateEquipmentLastServiceDate(
          record.equipmentId,
          mostRecent.serviceDate,
        );
      } else {
        // No more service records, clear the date
        await _clearEquipmentLastServiceDate(record.equipmentId);
      }
    }
  }

  /// Get all service records with upcoming due dates
  Future<List<domain.ServiceRecord>> getUpcomingServiceDue(
    int withinDays,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final threshold = DateTime.now()
        .add(Duration(days: withinDays))
        .millisecondsSinceEpoch;

    final results = await _db
        .customSelect(
          '''
      SELECT * FROM service_records
      WHERE next_service_due IS NOT NULL
        AND next_service_due > ?
        AND next_service_due <= ?
      ORDER BY next_service_due ASC
    ''',
          variables: [Variable.withInt(now), Variable.withInt(threshold)],
        )
        .get();

    return results.map(_mapCustomRowToServiceRecord).toList();
  }

  /// Get all overdue service records
  Future<List<domain.ServiceRecord>> getOverdueServices() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final results = await _db
        .customSelect(
          '''
      SELECT * FROM service_records
      WHERE next_service_due IS NOT NULL
        AND next_service_due < ?
      ORDER BY next_service_due ASC
    ''',
          variables: [Variable.withInt(now)],
        )
        .get();

    return results.map(_mapCustomRowToServiceRecord).toList();
  }

  /// Get service record count for an equipment item
  Future<int> getRecordCount(String equipmentId) async {
    final result = await _db
        .customSelect(
          '''
      SELECT COUNT(*) as count
      FROM service_records
      WHERE equipment_id = ?
    ''',
          variables: [Variable.withString(equipmentId)],
        )
        .getSingle();

    return result.data['count'] as int? ?? 0;
  }

  /// Update the equipment's lastServiceDate field
  Future<void> _updateEquipmentLastServiceDate(
    String equipmentId,
    DateTime serviceDate,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.equipment,
    )..where((t) => t.id.equals(equipmentId))).write(
      EquipmentCompanion(
        lastServiceDate: Value(serviceDate.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'equipment',
      recordId: equipmentId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Clear the equipment's lastServiceDate field
  Future<void> _clearEquipmentLastServiceDate(String equipmentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.equipment,
    )..where((t) => t.id.equals(equipmentId))).write(
      EquipmentCompanion(
        lastServiceDate: const Value(null),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'equipment',
      recordId: equipmentId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  domain.ServiceRecord _mapRowToServiceRecord(ServiceRecord row) {
    return domain.ServiceRecord(
      id: row.id,
      equipmentId: row.equipmentId,
      serviceCategory: _parseServiceCategory(row.serviceCategory),
      serviceKindId: row.serviceKindId,
      serviceDate: DateTime.fromMillisecondsSinceEpoch(row.serviceDate),
      provider: row.provider,
      cost: row.cost,
      currency: row.currency,
      nextServiceDue: row.nextServiceDue != null
          ? DateTime.fromMillisecondsSinceEpoch(row.nextServiceDue!)
          : null,
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  domain.ServiceRecord _mapCustomRowToServiceRecord(QueryRow row) {
    return domain.ServiceRecord(
      id: row.data['id'] as String,
      equipmentId: row.data['equipment_id'] as String,
      serviceCategory: _parseServiceCategory(
        row.data['service_category'] as String,
      ),
      serviceKindId: row.data['service_kind_id'] as String?,
      serviceDate: DateTime.fromMillisecondsSinceEpoch(
        row.data['service_date'] as int,
      ),
      provider: row.data['provider'] as String?,
      cost: (row.data['cost'] as num?)?.toDouble(),
      currency: row.data['currency'] as String? ?? 'USD',
      nextServiceDue: row.data['next_service_due'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              row.data['next_service_due'] as int,
            )
          : null,
      notes: (row.data['notes'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.data['updated_at'] as int,
      ),
    );
  }

  ServiceCategory _parseServiceCategory(String value) {
    return ServiceCategory.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ServiceCategory.other,
    );
  }
}
