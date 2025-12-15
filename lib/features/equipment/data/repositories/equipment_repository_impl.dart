import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/entities/equipment_item.dart';

class EquipmentRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();

  /// Get all active equipment
  Future<List<EquipmentItem>> getActiveEquipment() async {
    final query = _db.select(_db.equipment)
      ..where((t) => t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.type), (t) => OrderingTerm.asc(t.name)]);

    final rows = await query.get();
    return rows.map(_mapRowToEquipment).toList();
  }

  /// Get all retired equipment
  Future<List<EquipmentItem>> getRetiredEquipment() async {
    final query = _db.select(_db.equipment)
      ..where((t) => t.isActive.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    final rows = await query.get();
    return rows.map(_mapRowToEquipment).toList();
  }

  /// Get all equipment
  Future<List<EquipmentItem>> getAllEquipment() async {
    final query = _db.select(_db.equipment)
      ..orderBy([(t) => OrderingTerm.asc(t.type), (t) => OrderingTerm.asc(t.name)]);

    final rows = await query.get();
    return rows.map(_mapRowToEquipment).toList();
  }

  /// Get equipment by ID
  Future<EquipmentItem?> getEquipmentById(String id) async {
    final query = _db.select(_db.equipment)
      ..where((t) => t.id.equals(id));

    final row = await query.getSingleOrNull();
    return row != null ? _mapRowToEquipment(row) : null;
  }

  /// Get multiple equipment items by IDs
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final query = _db.select(_db.equipment)
      ..where((t) => t.id.isIn(ids));

    final rows = await query.get();
    return rows.map(_mapRowToEquipment).toList();
  }

  /// Create new equipment
  Future<EquipmentItem> createEquipment(EquipmentItem equipment) async {
    final id = equipment.id.isEmpty ? _uuid.v4() : equipment.id;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.equipment).insert(EquipmentCompanion(
      id: Value(id),
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
      lastServiceDate: Value(equipment.lastServiceDate?.millisecondsSinceEpoch),
      serviceIntervalDays: Value(equipment.serviceIntervalDays),
      notes: Value(equipment.notes),
      isActive: Value(equipment.isActive),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    return equipment.copyWith(id: id);
  }

  /// Update equipment
  Future<void> updateEquipment(EquipmentItem equipment) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_db.update(_db.equipment)..where((t) => t.id.equals(equipment.id))).write(
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
        lastServiceDate: Value(equipment.lastServiceDate?.millisecondsSinceEpoch),
        serviceIntervalDays: Value(equipment.serviceIntervalDays),
        notes: Value(equipment.notes),
        isActive: Value(equipment.isActive),
        updatedAt: Value(now),
      ),
    );
  }

  /// Delete equipment
  Future<void> deleteEquipment(String id) async {
    await (_db.delete(_db.equipment)..where((t) => t.id.equals(id))).go();
  }

  /// Mark equipment as serviced
  Future<void> markAsServiced(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
      EquipmentCompanion(
        lastServiceDate: Value(now.millisecondsSinceEpoch),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  /// Retire equipment
  Future<void> retireEquipment(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
      EquipmentCompanion(
        isActive: const Value(false),
        updatedAt: Value(now),
      ),
    );
  }

  /// Reactivate equipment
  Future<void> reactivateEquipment(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
      EquipmentCompanion(
        isActive: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Get equipment with service due
  Future<List<EquipmentItem>> getEquipmentWithServiceDue() async {
    final allEquipment = await getActiveEquipment();
    return allEquipment.where((g) => g.isServiceDue).toList();
  }

  /// Search equipment by name, brand, model, or serial number
  Future<List<EquipmentItem>> searchEquipment(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';

    final results = await _db.customSelect('''
      SELECT * FROM equipment
      WHERE LOWER(name) LIKE ?
         OR LOWER(brand) LIKE ?
         OR LOWER(model) LIKE ?
         OR LOWER(serial_number) LIKE ?
      ORDER BY is_active DESC, type ASC, name ASC
    ''', variables: [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
    ]).get();

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
            ? DateTime.fromMillisecondsSinceEpoch(row.data['purchase_date'] as int)
            : null,
        purchasePrice: (row.data['purchase_price'] as num?)?.toDouble(),
        purchaseCurrency: (row.data['purchase_currency'] as String?) ?? 'USD',
        lastServiceDate: row.data['last_service_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row.data['last_service_date'] as int)
            : null,
        serviceIntervalDays: row.data['service_interval_days'] as int?,
        notes: (row.data['notes'] as String?) ?? '',
        isActive: row.data['is_active'] == 1,
      );
    }).toList();
  }

  /// Get dive count for equipment item
  Future<int> getDiveCountForEquipment(String equipmentId) async {
    final result = await _db.customSelect('''
      SELECT COUNT(*) as count
      FROM dive_equipment
      WHERE equipment_id = ?
    ''', variables: [Variable.withString(equipmentId)]).getSingle();

    return result.data['count'] as int? ?? 0;
  }

  EquipmentItem _mapRowToEquipment(EquipmentData row) {
    return EquipmentItem(
      id: row.id,
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
    );
  }
}
