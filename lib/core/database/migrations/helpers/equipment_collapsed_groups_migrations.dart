part of '../app_database_migrations.dart';

/// The Equipment page's folded groups (v348, issue #4184).
extension EquipmentCollapsedGroupsMigrations on AppDatabase {
  /// `diver_settings.equipment_collapsed_groups` (v348, issue #4184). Nullable,
  /// no backfill: null reads as every group open. Safe from both the v348
  /// rung and the beforeOpen backstop.
  Future<void> _assertEquipmentCollapsedGroupsColumn() => _addColumnIfMissing(
    'diver_settings',
    'equipment_collapsed_groups',
    'TEXT',
  );
}
