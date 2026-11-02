import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/bootstrap/bootstrap_shared.dart';
import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/global_error_handler.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';

/// Starts the app in a browser.
///
/// No HTTP overrides, Windows migration or proxy controller: the browser owns
/// networking and has no app-data folders. Everything else matches the native
/// bootstrap, in the same order.
Future<void> bootstrapApp() => bootstrapWeb();

/// The browser bootstrap with its side effects injectable, so a VM test can
/// run it to the point of handing `runApp` its widget.
@visibleForTesting
Future<void> bootstrapWeb({
  void Function(Widget app) run = runApp,
  Future<SharedPreferences> Function() loadPreferences =
      SharedPreferences.getInstance,
  Future<String> Function() supportDirectory = AppDirectories.support,
  Future<void> Function() logEnvironment = logSessionEnvironment,
}) async {
  // Hold log lines in memory until the log file is attached below, so a
  // failure in the startup steps before it is not lost (#1826).
  LoggerService.bufferUntilFileAttached();
  WidgetsFlutterBinding.ensureInitialized();

  // Route uncaught Flutter framework and platform errors into the debug log
  // so crashes are diagnosable from the user-shared log (issue #318).
  installGlobalErrorHandlers();
  registerBundledLicenses();

  final prefs = await loadPreferences();
  applyStartupPreferences(prefs);

  final appSupportDir = await supportDirectory();
  final logFileService = await attachFileLogging(
    prefs,
    p.join(appSupportDir, 'logs'),
    logEnvironment: logEnvironment,
  );

  final locationService = DatabaseLocationService(prefs);
  run(
    buildStartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: locationService,
      demoPaths: DemoPaths(appSupportDir),
    ),
  );
}
