import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

/// A [BackupDatabaseAdapter] for tests whose code path never touches the
/// database: any call fails loudly instead of reaching a real one.
class UnusedBackupDatabaseAdapter implements BackupDatabaseAdapter {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'database not expected: ${invocation.memberName}',
  );

  @override
  AppDatabase get database => throw UnimplementedError();
}
