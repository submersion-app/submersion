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

  /// Swap the live database for [backupPath].
  ///
  /// [onMigrationProgress] fires per migration step when the restored file
  /// carries an older schema and the reopen runs the upgrade ladder — the only
  /// long-running phase of the swap, and otherwise invisible to the user.
  Future<void> restore(
    String backupPath, {
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  });
  Future<String> get databasePath;
  AppDatabase get database;

  /// The live database's SQLCipher key, or null when database password
  /// protection is off (the overwhelmingly common case).
  ///
  /// Needed only to deep-check a `BackupType.preMigration` artifact, which is
  /// a raw byte copy of the live file and is therefore SQLCipher ciphertext
  /// exactly when the live database is. Every other backup kind is a portable
  /// plaintext export and must keep failing validation loudly if it looks
  /// encrypted.
  String? get databaseKeyHex;
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
  Future<void> restore(
    String backupPath, {
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) =>
      _dbAdapter.restore(backupPath, onMigrationProgress: onMigrationProgress);

  @override
  Future<String> get databasePath => _dbAdapter.databasePath;

  @override
  AppDatabase get database => _dbAdapter.database;

  @override
  String? get databaseKeyHex => _dbAdapter.databaseKeyHex;
}

// coverage:ignore-end
