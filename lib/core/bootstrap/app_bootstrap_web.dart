import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/bootstrap/bootstrap_shared.dart';
import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/platform/browser_origin_storage.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/global_error_handler.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Starts the app in a browser.
///
/// No HTTP overrides, Windows migration or proxy controller: the browser owns
/// networking and has no app-data folders. Everything else matches the native
/// bootstrap, in the same order.
Future<void> bootstrapApp() => bootstrapWeb();

/// The semantics handle `?a11y=1` asks for, held for the page's life so the
/// tree stays on; a test disposes it.
@visibleForTesting
SemanticsHandle? bootstrapSemanticsHandle;

/// The browser bootstrap with its side effects injectable, so a VM test can
/// run it to the point of handing `runApp` its widget.
@visibleForTesting
Future<void> bootstrapWeb({
  void Function(Widget app) run = runApp,
  Future<SharedPreferences> Function() loadPreferences =
      SharedPreferences.getInstance,
  Future<String> Function() supportDirectory = AppDirectories.support,
  Future<void> Function() logEnvironment = logSessionEnvironment,
  Map<String, String>? queryParameters,
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

  // Forget this device in another tab leaves this one holding dives and
  // credentials in memory; a reload drops them (issue #4121).
  BrowserOriginStorage.onForgottenElsewhere(BrowserOriginStorage.reloadPage);

  final locationService = DatabaseLocationService(prefs);
  run(
    buildStartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: locationService,
      // Demo mode reads sample files from disk; a browser has none.
      demoPaths: null,
    ),
  );
  // The smoke runner reads Flutter's semantics tree, which a page only
  // builds once a screen reader asks; `?a11y=1` asks from the first frame
  // (issue #4121).
  if ((queryParameters ?? Uri.base.queryParameters)['a11y'] == '1') {
    bootstrapSemanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
  }
}
