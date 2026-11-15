part of '../app_database_migrations.dart';

/// The unit an equipment number reads in (v368, issue #4534).
extension AttributeUnitMigrations on AppDatabase {
  /// `equipment_attributes.value_unit`. Nullable, so an older peer omits it
  /// and a row made before this column follows the diver's settings. Safe
  /// from both the v368 rung and the beforeOpen backstop.
  Future<void> _assertAttributeValueUnitColumn() =>
      _addColumnIfMissing('equipment_attributes', 'value_unit', 'TEXT');

  /// The beforeOpen backstop: a database stamped at or past v368 by a build
  /// that never ran this rung (a colliding schema claim, a restore) gets the
  /// column and, since it then also missed the repair, the repair too. A
  /// database that has the column already ran both, so it is left alone.
  Future<void> _healAttributeValueUnitColumn() async {
    final skipped =
        await _tableExists('equipment_attributes') &&
        !await _columnExists('equipment_attributes', 'value_unit');
    await _assertAttributeValueUnitColumn();
    if (skipped) await _repairCylinderVolumeCubicFeet();
  }

  /// v368: [repairCylinderVolumeCubicFeet] (issue #4534). Guarded on the
  /// tables, as the other helpers are, for migration fixtures that build
  /// only part of the schema.
  Future<void> _repairCylinderVolumeCubicFeet() async {
    if (await _columnExists('equipment_attributes', 'value_num') &&
        await _columnExists('equipment', 'type')) {
      await repairCylinderVolumeCubicFeet(this);
    }
  }
}
