import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Thin interface for the database operations BackupService needs.
///
/// Allows injecting a fake in tests without depending on the
/// [DatabaseService] singleton directly. Lives in its own file so both
/// `backup_service.dart` and `backup_target.dart` can depend on it without a
/// circular import.
abstract class BackupDatabaseAdapter {
  Future<void> backup(String destinationPath);
  Future<void> restore(String backupPath);
  Future<String> get databasePath;
  AppDatabase get database;
}

/// Default adapter that delegates to [DatabaseService.instance].
///
/// Pure production glue around the private-constructor singleton (which cannot
/// be faked), so tests exercise the [BackupDatabaseAdapter] interface via fakes
/// and this delegation is excluded from coverage.
// coverage:ignore-start
class DefaultBackupDatabaseAdapter implements BackupDatabaseAdapter {
  final DatabaseService _dbAdapter;

  const DefaultBackupDatabaseAdapter(this._dbAdapter);

  @override
  Future<void> backup(String destinationPath) =>
      _dbAdapter.backup(destinationPath);

  @override
  Future<void> restore(String backupPath) => _dbAdapter.restore(backupPath);

  @override
  Future<String> get databasePath => _dbAdapter.databasePath;

  @override
  AppDatabase get database => _dbAdapter.database;
}

// coverage:ignore-end
