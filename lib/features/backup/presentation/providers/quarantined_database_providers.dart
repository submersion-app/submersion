import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/backup/data/services/quarantined_database_service.dart';
import 'package:submersion/features/backup/domain/entities/quarantined_database.dart';

/// Lists and deletes the database copies a restore set aside (issue #1923).
final quarantinedDatabaseServiceProvider = Provider<QuarantinedDatabaseService>(
  (ref) => QuarantinedDatabaseService(
    databasePath: () => DatabaseService.instance.databasePath,
    keyHex: () => DatabaseService.instance.databaseKeyHex,
  ),
);

/// The database copies a restore set aside next to the live database,
/// newest first.
final quarantinedDatabasesProvider = FutureProvider<List<QuarantinedDatabase>>(
  (ref) => ref.watch(quarantinedDatabaseServiceProvider).find(),
);
