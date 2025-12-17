import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../domain/entities/equipment_set.dart' as domain;
import 'equipment_repository_impl.dart';

class EquipmentSetRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _equipmentRepo = EquipmentRepository();

  /// Get all equipment sets
  Future<List<domain.EquipmentSet>> getAllSets() async {
    final query = _db.select(_db.equipmentSets)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    final rows = await query.get();

    final sets = <domain.EquipmentSet>[];
    for (final row in rows) {
      final equipmentIds = await getEquipmentIdsInSet(row.id);
      sets.add(_mapRowToSet(row, equipmentIds));
    }
    return sets;
  }

  /// Get set by ID
  Future<domain.EquipmentSet?> getSetById(String id, {bool includeItems = false}) async {
    final query = _db.select(_db.equipmentSets)
      ..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final equipmentIds = await getEquipmentIdsInSet(id);
    var set = _mapRowToSet(row, equipmentIds);

    if (includeItems) {
      final items = await _equipmentRepo.getEquipmentByIds(equipmentIds);
      set = set.copyWith(items: items);
    }
    return set;
  }

  /// Get equipment IDs in a set
  Future<List<String>> getEquipmentIdsInSet(String setId) async {
    final query = _db.select(_db.equipmentSetItems)
      ..where((t) => t.setId.equals(setId));
    final rows = await query.get();
    return rows.map((r) => r.equipmentId).toList();
  }

  /// Create a new equipment set
  Future<domain.EquipmentSet> createSet(domain.EquipmentSet set) async {
    final id = set.id.isEmpty ? _uuid.v4() : set.id;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.equipmentSets).insert(EquipmentSetsCompanion(
      id: Value(id),
      name: Value(set.name),
      description: Value(set.description),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    // Add equipment items to set
    for (final equipmentId in set.equipmentIds) {
      await _db.into(_db.equipmentSetItems).insert(
        EquipmentSetItemsCompanion(
          setId: Value(id),
          equipmentId: Value(equipmentId),
        ),
      );
    }

    return set.copyWith(
      id: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// Update an equipment set
  Future<void> updateSet(domain.EquipmentSet set) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(_db.equipmentSets)..where((t) => t.id.equals(set.id)))
        .write(EquipmentSetsCompanion(
      name: Value(set.name),
      description: Value(set.description),
      updatedAt: Value(now),
    ));

    // Update equipment items: delete and re-insert
    await (_db.delete(_db.equipmentSetItems)
          ..where((t) => t.setId.equals(set.id)))
        .go();
    for (final equipmentId in set.equipmentIds) {
      await _db.into(_db.equipmentSetItems).insert(
        EquipmentSetItemsCompanion(
          setId: Value(set.id),
          equipmentId: Value(equipmentId),
        ),
      );
    }
  }

  /// Delete an equipment set
  Future<void> deleteSet(String id) async {
    await (_db.delete(_db.equipmentSets)..where((t) => t.id.equals(id))).go();
  }

  /// Add equipment item to set
  Future<void> addItemToSet(String setId, String equipmentId) async {
    await _db.into(_db.equipmentSetItems).insert(
      EquipmentSetItemsCompanion(
        setId: Value(setId),
        equipmentId: Value(equipmentId),
      ),
    );
    // Update the set's updatedAt timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentSets)..where((t) => t.id.equals(setId)))
        .write(EquipmentSetsCompanion(updatedAt: Value(now)));
  }

  /// Remove equipment item from set
  Future<void> removeItemFromSet(String setId, String equipmentId) async {
    await (_db.delete(_db.equipmentSetItems)
          ..where((t) => t.setId.equals(setId) & t.equipmentId.equals(equipmentId)))
        .go();
    // Update the set's updatedAt timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentSets)..where((t) => t.id.equals(setId)))
        .write(EquipmentSetsCompanion(updatedAt: Value(now)));
  }

  domain.EquipmentSet _mapRowToSet(EquipmentSet row, List<String> equipmentIds) {
    return domain.EquipmentSet(
      id: row.id,
      name: row.name,
      description: row.description,
      equipmentIds: equipmentIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
