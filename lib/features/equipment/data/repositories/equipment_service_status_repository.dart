import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// One item's cached verdict: a `ServiceClockSeverity` name and the worst
/// clock's date trigger, epoch ms, when it has one.
typedef ServiceStatusEntry = ({String severity, int? dueDate});

/// The local service-due cache (`equipment_service_status`, v242): each
/// active item's worst severity for the active diver, as the engine last
/// evaluated it (#2365 PR 3). Written only through [replaceAll], which
/// writes nothing when nothing changed, so a steady list does not
/// re-query.
class EquipmentServiceStatusRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(EquipmentServiceStatusRepository);

  Future<Map<String, String>> severities() async => {
    for (final r in await _db.select(_db.equipmentServiceStatus).get())
      r.equipmentId: r.severity,
  };

  /// Makes the cache hold exactly [byId]: rows for other items go, new or
  /// changed verdicts are written, unchanged ones are left alone. One
  /// transaction, and a verdict for an item deleted since the engine
  /// evaluated it is skipped rather than failing the equipment foreign key.
  Future<void> replaceAll(
    Map<String, ServiceStatusEntry> byId, {
    required int computedAt,
  }) async {
    try {
      await _db.transaction(() => _replaceAll(byId, computedAt));
    } catch (e, st) {
      _log.error(
        'Failed to write the service status cache',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _replaceAll(
    Map<String, ServiceStatusEntry> byId,
    int computedAt,
  ) async {
    final existing = {
      for (final r in await _db.select(_db.equipmentServiceStatus).get())
        r.equipmentId: r,
    };
    final live = byId.isEmpty
        ? const <String>{}
        : {
            for (final r
                in await (_db.selectOnly(_db.equipment)
                      ..addColumns([_db.equipment.id])
                      ..where(_db.equipment.id.isIn(byId.keys)))
                    .get())
              r.read(_db.equipment.id)!,
          };
    final stale = [
      for (final id in existing.keys)
        if (!live.contains(id)) id,
    ];
    final changed = {
      for (final e in byId.entries)
        if (live.contains(e.key) &&
            (existing[e.key]?.severity != e.value.severity ||
                existing[e.key]?.dueDate != e.value.dueDate))
          e.key: e.value,
    };
    if (stale.isEmpty && changed.isEmpty) return;
    await _db.batch((b) {
      if (stale.isNotEmpty) {
        b.deleteWhere(
          _db.equipmentServiceStatus,
          (t) => t.equipmentId.isIn(stale),
        );
      }
      for (final e in changed.entries) {
        b.insert(
          _db.equipmentServiceStatus,
          EquipmentServiceStatusCompanion.insert(
            equipmentId: e.key,
            severity: e.value.severity,
            dueDate: Value(e.value.dueDate),
            computedAt: computedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
