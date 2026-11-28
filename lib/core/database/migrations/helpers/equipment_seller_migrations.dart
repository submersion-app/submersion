part of '../app_database_migrations.dart';

/// Who sold a gear item (issue #5140).
extension EquipmentSellerMigrations on AppDatabase {
  /// v397: equipment.seller_buddy_id and equipment.seller_dive_center_id,
  /// nullable links with SET NULL foreign keys and no backfill: an existing
  /// item keeps its typed retailer with no link. Idempotent; called from the
  /// v397 onUpgrade step and the beforeOpen backstop.
  Future<void> _assertEquipmentSellerColumns() async {
    if (!await _tableExists('equipment')) return;
    await _addColumnIfMissing(
      'equipment',
      'seller_buddy_id',
      'TEXT REFERENCES buddies(id) ON DELETE SET NULL',
    );
    await _addColumnIfMissing(
      'equipment',
      'seller_dive_center_id',
      'TEXT REFERENCES dive_centers(id) ON DELETE SET NULL',
    );
  }
}
