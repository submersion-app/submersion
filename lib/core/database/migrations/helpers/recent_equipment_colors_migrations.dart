part of '../app_database_migrations.dart';

/// The custom colours a diver picked for their gear (v365, issue #4537).
extension RecentEquipmentColorsMigrations on AppDatabase {
  /// `diver_settings.recent_equipment_colors` (v365, issue #4537). Nullable,
  /// no backfill: null reads as no remembered colours. Safe from both the
  /// v365 rung and the beforeOpen backstop.
  Future<void> _assertRecentEquipmentColorsColumn() =>
      _addColumnIfMissing('diver_settings', 'recent_equipment_colors', 'TEXT');
}
