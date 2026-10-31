part of 'app_database_migrations.dart';

/// The change log's beforeOpen step (issue #3922). Split from
/// before_open.dart, which is at the 800-line limit.
extension ChangeLogBackstop on AppDatabase {
  /// Re-asserts the log tables, for a database arriving by restore already
  /// at the current version. A failure here is logged and never rethrown:
  /// logging must never stop the app opening.
  Future<void> _assertChangeLogTables() async {
    try {
      await _assertChangeLogSchema();
    } catch (error, stackTrace) {
      developer.log(
        'Could not assert the change log tables',
        name: 'ChangeLog',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
