part of '../app_database_migrations.dart';

/// The unit an equipment number reads in (v367, issue #4534).
extension AttributeUnitMigrations on AppDatabase {
  /// `equipment_attributes.value_unit`. Nullable, so an older peer omits it
  /// and a row made before this column follows the diver's settings. Safe
  /// from both the v367 rung and the beforeOpen backstop.
  Future<void> _assertAttributeValueUnitColumn() =>
      _addColumnIfMissing('equipment_attributes', 'value_unit', 'TEXT');

  /// v367: [repairCylinderVolumeCubicFeet] (issue #4534). Guarded on the
  /// tables, as the other helpers are, for migration fixtures that build
  /// only part of the schema.
  Future<void> _repairCylinderVolumeCubicFeet() async {
    if (await _columnExists('equipment_attributes', 'value_num') &&
        await _columnExists('equipment', 'type')) {
      await repairCylinderVolumeCubicFeet(this);
    }
  }
}
