import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart'
    as domain;

/// CRUD for the service-kind catalog. Built-ins are reference data:
/// they cannot be edited or deleted here, are skipped by sync export,
/// and are re-seeded in beforeOpen.
class ServiceKindRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Built-ins plus the diver's custom kinds (all custom kinds when
  /// [diverId] is null).
  Future<List<domain.ServiceKind>> getAllKinds({String? diverId}) async {
    final query = _db.select(_db.serviceKinds)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (diverId != null) {
      query.where(
        (t) =>
            t.isBuiltIn.equals(true) |
            t.diverId.isNull() |
            t.diverId.equals(diverId),
      );
    }
    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  Future<domain.ServiceKind?> getKindById(String id) async {
    final row = await (_db.select(
      _db.serviceKinds,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Future<domain.ServiceKind> createKind(domain.ServiceKind kind) async {
    final id = kind.id.isEmpty ? _uuid.v4() : kind.id;
    final now = DateTime.now();
    await _db
        .into(_db.serviceKinds)
        .insert(
          ServiceKindsCompanion(
            id: Value(id),
            diverId: Value(kind.diverId),
            name: Value(kind.name),
            applicableTypes: Value(
              jsonEncode(kind.applicableTypes.map((t) => t.name).toList()),
            ),
            defaultIntervalDays: Value(kind.defaultIntervalDays),
            defaultIntervalDives: Value(kind.defaultIntervalDives),
            defaultIntervalHours: Value(kind.defaultIntervalHours),
            autoAttach: Value(kind.autoAttach),
            isBuiltIn: const Value(false),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'serviceKinds',
      recordId: id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
    return kind.copyWith(
      id: id,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateKind(domain.ServiceKind kind) async {
    if (kind.isBuiltIn) {
      throw StateError('Built-in service kinds cannot be edited');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.serviceKinds,
    )..where((t) => t.id.equals(kind.id) & t.isBuiltIn.equals(false))).write(
      ServiceKindsCompanion(
        name: Value(kind.name),
        applicableTypes: Value(
          jsonEncode(kind.applicableTypes.map((t) => t.name).toList()),
        ),
        defaultIntervalDays: Value(kind.defaultIntervalDays),
        defaultIntervalDives: Value(kind.defaultIntervalDives),
        defaultIntervalHours: Value(kind.defaultIntervalHours),
        autoAttach: Value(kind.autoAttach),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'serviceKinds',
      recordId: kind.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a custom kind. Schedules referencing it are cascade-deleted by
  /// SQLite, so each is tombstoned explicitly (cascades emit no deletion-log
  /// entries; a peer would resurrect them otherwise).
  Future<void> deleteKind(String id) async {
    final row = await (_db.select(
      _db.serviceKinds,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.isBuiltIn) {
      throw StateError('Built-in service kinds cannot be deleted');
    }
    await _db.transaction(() async {
      final schedules = await (_db.select(
        _db.serviceSchedules,
      )..where((t) => t.serviceKindId.equals(id))).get();
      await (_db.delete(_db.serviceKinds)..where((t) => t.id.equals(id))).go();
      for (final s in schedules) {
        await _syncRepository.logDeletion(
          entityType: 'serviceSchedules',
          recordId: s.id,
        );
      }
      await _syncRepository.logDeletion(
        entityType: 'serviceKinds',
        recordId: id,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  domain.ServiceKind _mapRow(ServiceKindRow row) {
    final typeNames = (jsonDecode(row.applicableTypes) as List<dynamic>)
        .cast<String>();
    return domain.ServiceKind(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      applicableTypes: typeNames
          .map(
            (s) => EquipmentType.values.firstWhere(
              (t) => t.name == s,
              orElse: () => EquipmentType.other,
            ),
          )
          .toList(),
      defaultIntervalDays: row.defaultIntervalDays,
      defaultIntervalDives: row.defaultIntervalDives,
      defaultIntervalHours: row.defaultIntervalHours,
      autoAttach: row.autoAttach,
      isBuiltIn: row.isBuiltIn,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
