import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Opens the database demo mode switches between: the sample logbook on the
/// way in, the user's own logbook on the way out.
abstract class DemoDatabaseSwitcher {
  /// Closes the open database and opens [path] with [keyHex] (null for a
  /// plaintext file such as the sample logbook).
  Future<void> openAt(String path, {required String? keyHex});

  AppDatabase get current;
}

/// The production switcher over [DatabaseService.instance], using the same
/// verified close-and-reopen that restore and "open folder" use.
class DatabaseServiceDemoSwitcher implements DemoDatabaseSwitcher {
  const DatabaseServiceDemoSwitcher();

  @override
  AppDatabase get current => DatabaseService.instance.database;

  @override
  Future<void> openAt(String path, {required String? keyHex}) async {
    final service = DatabaseService.instance;
    final previousKey = service.databaseKeyHex;
    service.databaseKeyHex = keyHex;
    try {
      await service.reinitializeAtPath(path);
    } catch (_) {
      service.databaseKeyHex = previousKey;
      rethrow;
    }
  }
}
