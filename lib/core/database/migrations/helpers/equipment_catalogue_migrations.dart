part of '../app_database_migrations.dart';

/// An item's link to its equipment catalogue record (v388, issue #5118).
extension EquipmentCatalogueMigrations on AppDatabase {
  /// `equipment.catalogue_id` and `equipment.catalogue_answers`. Both
  /// nullable, so an older peer omits them and a row from before simply has
  /// none. Safe from both the v388 rung and the beforeOpen backstop.
  Future<void> _assertEquipmentCatalogueColumns() async {
    await _addColumnIfMissing('equipment', 'catalogue_id', 'TEXT');
    await _addColumnIfMissing('equipment', 'catalogue_answers', 'TEXT');
  }
}
