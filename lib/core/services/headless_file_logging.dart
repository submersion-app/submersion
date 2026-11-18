import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// A Workmanager task: true when it is done, false to have it retried.
typedef HeadlessTask =
    Future<bool> Function(String task, Map<String, dynamic>? inputData);

/// [task], made to write every line it logged before it returns: the
/// headless isolate is torn down as soon as a task returns, and lines still
/// queued for the log file would go with it (issue #4572).
HeadlessTask flushingLogs(HeadlessTask task) => (name, inputData) async {
  try {
    return await task(name, inputData);
  } finally {
    await LoggerService.flushPendingWrites();
  }
};

/// Attaches the debug log file in a headless isolate (the WorkManager
/// isolate that runs scheduled backups), as the app's startup does in the
/// foreground (issue #4572). Without it nothing a background task logs,
/// warnings and errors included, reached the log a diver exports.
///
/// Same file and same levels as the foreground: warnings and errors always,
/// debug and info lines only in debug mode. Returns false when the file
/// cannot be attached; that never fails the task.
///
/// [supportDirectory] is a test seam for the app-support directory.
Future<bool> attachHeadlessFileLogging(
  SharedPreferences prefs, {
  Future<String> Function() supportDirectory = AppDirectories.support,
}) async {
  try {
    final logFileService = LogFileService(
      logDirectory: p.join(await supportDirectory(), 'logs'),
      // Trims once when attached, then only appends; see
      // [LogFileService.rotates].
      rotates: false,
    );
    await logFileService.initialize();
    LoggerService.configureFileLogging(
      logFileService,
      verbose: prefs.getBool(LoggerService.debugModePrefKey) ?? false,
    );
    return true;
  } catch (e) {
    const LoggerService(
      'BackgroundService',
    ).warning('Background log file not attached: $e');
    return false;
  }
}
