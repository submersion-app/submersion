part of '../app_database_migrations.dart';

/// The unit an equipment number reads in (v366, issue #4534).
extension AttributeUnitMigrations on AppDatabase {
  /// `equipment_attributes.value_unit`. Nullable, so an older peer omits it
  /// and a row made before this column follows the diver's settings. Safe
  /// from both the v366 rung and the beforeOpen backstop.
  Future<void> _assertAttributeValueUnitColumn() =>
      _addColumnIfMissing('equipment_attributes', 'value_unit', 'TEXT');
}
