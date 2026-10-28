part of '../app_database_migrations.dart';

/// Each list's saved sort and grouping, Equipment's arrangement, and the
/// clock they sync under (issue #3748).
extension ListArrangementMigrations on AppDatabase {
  /// The value columns, all nullable: null reads as the list's starting
  /// order, so adding them changes nothing a diver sees.
  static const _valueColumns = {
    'dive_list_sort': 'TEXT',
    'dive_plan_list_sort': 'TEXT',
    'trip_list_sort': 'TEXT',
    'course_list_sort': 'TEXT',
    'buddy_list_sort': 'TEXT',
    'dive_center_list_sort': 'TEXT',
    'site_list_sort': 'TEXT',
    'certification_list_sort': 'TEXT',
    'equipment_list_sort': 'TEXT',
    'site_list_group_by': 'TEXT',
    'certification_list_group_by': 'TEXT',
    'equipment_arrangement': 'TEXT',
    'equipment_group_by_location':
        'INTEGER CHECK (equipment_group_by_location IN (0, 1))',
  };

  /// v323: adds the columns, then gives every row that has a row clock a
  /// group clock equal to it. Idempotent; called from the rung and the
  /// beforeOpen backstop.
  ///
  /// The clock is the one thing filled. A row-clock write fills a null group
  /// clock with the NEW row clock (SyncRepository._stampHlc), so without
  /// this the first unrelated settings save after the upgrade would make
  /// this device's untouched arrangement look newer than one a diver chose
  /// on another device. The row clock is an honest bound: the arrangement
  /// columns (the view modes and group-trips toggle) last changed no later
  /// than it.
  Future<void> _assertListArrangementColumns() async {
    for (final entry in _valueColumns.entries) {
      await _addColumnIfMissing('diver_settings', entry.key, entry.value);
    }
    await _addColumnIfMissing('diver_settings', 'list_arrangement_hlc', 'TEXT');
    if (!await _columnExists('diver_settings', 'hlc')) return;
    await customStatement(
      'UPDATE diver_settings SET list_arrangement_hlc = hlc '
      'WHERE list_arrangement_hlc IS NULL AND hlc IS NOT NULL',
    );
  }
}
