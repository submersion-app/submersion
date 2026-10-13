import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/compaction/database_compaction_prefs.dart';
import 'package:submersion/core/database/compaction/database_space.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Decides, while the app runs, whether the next launch should compact the
/// database (issue #3333). Measuring here rather than at launch spares
/// every start an extra exclusive connection just to read three pragmas.
class DatabaseCompactionMonitor {
  DatabaseCompactionMonitor({
    required Future<DatabaseSpace> Function() readSpace,
    required DatabaseCompactionPrefs prefs,
  }) : _readSpace = readSpace,
       _prefs = prefs;

  final Future<DatabaseSpace> Function() _readSpace;
  final DatabaseCompactionPrefs _prefs;

  /// True when it asked the next launch to compact.
  Future<bool> check() async {
    if (_prefs.isRequested || _prefs.inBackoff) return false;
    if (!(await _readSpace()).worthCompacting) return false;
    // Asked again after the measurement's await: a Cancel the diver tapped
    // meanwhile must win. Nothing awaits between this check and the write.
    if (_prefs.isRequested || _prefs.inBackoff) return false;
    await _prefs.request();
    return true;
  }
}

/// Runs [DatabaseCompactionMonitor] against the open database. Called after
/// the writes that free the most space (a document delete, gear files moved
/// into Documents) and once per launch. Contains its own failures.
// no-tick: the value is a CLOSURE, not a query result.
final databaseCompactionMonitorProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    try {
      await DatabaseCompactionMonitor(
        readSpace: () => readDatabaseSpace(DatabaseService.instance.database),
        prefs: DatabaseCompactionPrefs(await SharedPreferences.getInstance()),
      ).check();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(
        DatabaseCompactionMonitor,
      ).warning('Compaction check failed', error: e, stackTrace: stackTrace);
    }
  };
});
