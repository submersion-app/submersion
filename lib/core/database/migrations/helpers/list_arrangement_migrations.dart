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

  /// v323: adds the columns, then, only when it has just added the clock,
  /// gives every row that has a row clock a group clock equal to it.
  /// Idempotent; called from the rung and the beforeOpen backstop. Once the
  /// column exists, a null clock means "never arranged" and is left alone:
  /// filling it on a later open would hand it an unrelated save's clock.
  ///
  /// The clock is the one thing filled. The view modes and group-trips
  /// toggle in the group were last changed under the row clock, so the row
  /// clock is their honest clock: copied, a peer's later arrangement change
  /// still wins and an earlier one still loses. A row with no row clock keeps
  /// a null arrangement clock, which reads as never set
  /// (SyncFactGroup.nullClockIsUnset) and loses to any peer change.
  Future<void> _assertListArrangementColumns() async {
    for (final entry in _valueColumns.entries) {
      await _addColumnIfMissing('diver_settings', entry.key, entry.value);
    }
    final clockExisted = await _columnExists(
      'diver_settings',
      'list_arrangement_hlc',
    );
    await _addColumnIfMissing('diver_settings', 'list_arrangement_hlc', 'TEXT');
    if (clockExisted || !await _columnExists('diver_settings', 'hlc')) return;
    await customStatement(
      'UPDATE diver_settings SET list_arrangement_hlc = hlc '
      'WHERE list_arrangement_hlc IS NULL AND hlc IS NOT NULL',
    );
  }
}
