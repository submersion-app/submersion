import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

/// CRUD for a diver's named places (v268). A place any move references can
/// only be archived, so history never loses a name.
class EquipmentLocationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String entity = 'equipmentLocations';

  /// Emits when a place is written or removed, here or by a sync.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.equipmentLocations));

  /// The diver's places plus any without a diver, by name; every place when
  /// [diverId] is null. Archived places included: callers filter.
  Future<List<EquipmentLocation>> getLocations({String? diverId}) async {
    final query = _db.select(_db.equipmentLocations);
    if (diverId != null) {
      query.where((t) => t.diverId.isNull() | t.diverId.equals(diverId));
    }
    final rows = await query.get();
    return sortedByText(rows, (r) => r.name).map(_toDomain).toList();
  }

  Future<EquipmentLocation?> getLocation(String id) async {
    final row = await (_db.select(
      _db.equipmentLocations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Creates a place. A blank [name] throws [ArgumentError].
  Future<EquipmentLocation> createLocation({
    required String? diverId,
    required String name,
    required EquipmentLocationKind kind,
    String notes = '',
  }) async {
    final trimmed = _requireName(name);
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    // Each write and its sync mark in one transaction, so a place is never
    // kept without being queued for sync.
    await _db.transaction(() async {
      await _db
          .into(_db.equipmentLocations)
          .insert(
            EquipmentLocationsCompanion.insert(
              id: id,
              diverId: Value(diverId),
              name: trimmed,
              kind: Value(kind.name),
              notes: Value(notes.trim()),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _markPending(id, now);
    });
    SyncEventBus.notifyLocalChange();
    return (await getLocation(id))!;
  }

  /// Saves [location]'s name, kind, notes and archived flag.
  Future<void> updateLocation(EquipmentLocation location) async {
    final trimmed = _requireName(location.name);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(
        _db.equipmentLocations,
      )..where((t) => t.id.equals(location.id))).write(
        EquipmentLocationsCompanion(
          name: Value(trimmed),
          kind: Value(location.kind.name),
          notes: Value(location.notes.trim()),
          isArchived: Value(location.isArchived),
          updatedAt: Value(now),
        ),
      );
      await _markPending(location.id, now);
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(
        _db.equipmentLocations,
      )..where((t) => t.id.equals(id))).write(
        EquipmentLocationsCompanion(
          isArchived: Value(archived),
          updatedAt: Value(now),
        ),
      );
      await _markPending(id, now);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Whether any move, current or historical, names the place.
  Future<bool> isInUse(String id) async {
    final row =
        await (_db.selectOnly(_db.equipmentLocationMoves)
              ..addColumns([_db.equipmentLocationMoves.id])
              ..where(_db.equipmentLocationMoves.locationId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Deletes a never-used place and tombstones it. A place any move names
  /// throws [StateError]: archive it instead, so its history keeps a name.
  Future<void> deleteLocation(String id) async {
    await _db.transaction(() async {
      if (await isInUse(id)) {
        throw StateError('A place in use can only be archived');
      }
      await (_db.delete(
        _db.equipmentLocations,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entity, recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// The diver's place named [name] ignoring case, an active one before an
  /// archived one; failing both, a new place of kind other. For imports.
  Future<EquipmentLocation> findOrCreateByName({
    required String? diverId,
    required String name,
  }) async {
    final wanted = name.trim().toLowerCase();
    final matches = [
      for (final l in await getLocations(diverId: diverId))
        if (l.name.toLowerCase() == wanted) l,
    ];
    for (final l in matches) {
      if (!l.isArchived) return l;
    }
    if (matches.isNotEmpty) return matches.first;
    return createLocation(
      diverId: diverId,
      name: name,
      kind: EquipmentLocationKind.other,
    );
  }

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A place needs a name');
    }
    return trimmed;
  }

  Future<void> _markPending(String id, int now) => _syncRepository
      .markRecordPending(entityType: entity, recordId: id, localUpdatedAt: now);

  EquipmentLocation _toDomain(EquipmentLocationRow r) => EquipmentLocation(
    id: r.id,
    diverId: r.diverId,
    name: r.name,
    kind: EquipmentLocationKind.fromName(r.kind),
    notes: r.notes,
    isArchived: r.isArchived,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );
}
