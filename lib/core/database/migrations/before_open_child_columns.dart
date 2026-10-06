part of 'app_database_migrations.dart';

/// Column-only backstops for child rows that every read selects whole, split
/// out of before_open.dart to keep it under the migration file size limit.
extension BeforeOpenChildColumns on AppDatabase {
  /// Re-asserts columns a database that arrived by restore or sync-adopt, or
  /// one a renumbered rung skipped, may lack. Each is column only, with no
  /// backfill, so none can touch diver data.
  Future<void> _assertChildRowColumns() async {
    // v194: dive_tanks.transmitter_serial. Every tank read selects the whole
    // row, so a database without the rung would throw on the first read.
    await _assertTankTransmitterSerialColumn();

    // v254: dive_tanks.role_source, for the same reason.
    await _assertTankRoleSourceColumn();

    // v259: dive_tanks.usage_duration (issue #1496).
    await _assertTankUsageDurationColumn();

    // v270: the weight name columns (issue #956), defaulted to ''.
    await _assertWeightLabelColumns();
  }
}
