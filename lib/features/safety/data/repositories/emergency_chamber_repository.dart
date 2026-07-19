import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';

/// Persistence for user-added hyperbaric chamber entries (HLC parent,
/// synced). Bundled chambers are asset-resident and never touch this table.
class EmergencyChamberRepository {
  db.AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// User-added chambers for [diverId], plus any legacy/global entries with a
  /// null diverId. When [diverId] is null (no active diver) all rows are
  /// returned. Mirrors the per-diver scoping used by checklist templates.
  Future<List<EmergencyChamber>> getUserChambers({String? diverId}) async {
    final query = _db.select(_db.emergencyChambers)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
    }
    final rows = await query.get();
    return [for (final row in rows) _toDomain(row)];
  }

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.emergencyChambers));

  Future<EmergencyChamber> createChamber({
    required String name,
    required String country,
    required String phone,
    String? city,
    double? latitude,
    double? longitude,
    String? notes,
    String? diverId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.emergencyChambers)
        .insert(
          db.EmergencyChambersCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: name,
            country: country,
            city: Value(city),
            phone: phone,
            latitude: Value(latitude),
            longitude: Value(longitude),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'emergencyChambers',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return EmergencyChamber(
      id: id,
      name: name,
      country: country,
      city: city,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      isBuiltIn: false,
    );
  }

  Future<void> deleteChamber(String id) async {
    await (_db.delete(
      _db.emergencyChambers,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(
      entityType: 'emergencyChambers',
      recordId: id,
    );
    SyncEventBus.notifyLocalChange();
  }

  EmergencyChamber _toDomain(db.EmergencyChamber row) {
    return EmergencyChamber(
      id: row.id,
      name: row.name,
      country: row.country,
      city: row.city,
      phone: row.phone,
      latitude: row.latitude,
      longitude: row.longitude,
      notes: row.notes,
      isBuiltIn: false,
    );
  }
}
