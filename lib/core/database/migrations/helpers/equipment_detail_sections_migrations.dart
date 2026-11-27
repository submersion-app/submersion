part of '../app_database_migrations.dart';

/// The gear item page's card order and visibility (v391, issue #4975).
extension EquipmentDetailSectionsMigrations on AppDatabase {
  /// `diver_settings.equipment_detail_sections` (TEXT, nullable). No
  /// backfill: null reads as the order the page always had. Safe from both
  /// the v391 rung and the beforeOpen backstop.
  Future<void> _assertEquipmentDetailSectionsColumn() async {
    await _addColumnIfMissing(
      'diver_settings',
      'equipment_detail_sections',
      'TEXT',
    );
  }
}
