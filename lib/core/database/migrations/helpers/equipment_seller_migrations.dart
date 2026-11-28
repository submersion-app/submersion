part of '../app_database_migrations.dart';

/// Who sold a gear item (issue #5140).
extension EquipmentSellerMigrations on AppDatabase {
  /// v397: equipment.seller_buddy_id and equipment.seller_dive_center_id,
  /// nullable links with SET NULL foreign keys and no backfill: an existing
  /// item keeps its typed retailer with no link. Idempotent; called from the
  /// v397 onUpgrade step and the beforeOpen backstop.
  ///
  /// A foreign key names its parent only when that table exists: SQLite
  /// refuses every write to `equipment` while it references a missing
  /// table, and a database that old has no buddy or centre to link.
  Future<void> _assertEquipmentSellerColumns() async {
    if (!await _tableExists('equipment')) return;
    Future<String> link(String parent) async => await _tableExists(parent)
        ? 'TEXT REFERENCES $parent(id) ON DELETE SET NULL'
        : 'TEXT';
    await _addColumnIfMissing(
      'equipment',
      'seller_buddy_id',
      await link('buddies'),
    );
    await _addColumnIfMissing(
      'equipment',
      'seller_dive_center_id',
      await link('dive_centers'),
    );
  }
}
