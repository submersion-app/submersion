import 'dart:async';

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
import 'package:submersion/core/services/web_library_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/media/data/streaming/media_stream_worker_host.dart';

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
  Future<void> Function(String activePath) sweepLibraries =
      sweepSupersededWebLibraries,
}) async {
  // Hold log lines in memory until the log file is attached below, so a
  // failure in the startup steps before it is not lost (#1826).
  LoggerService.bufferUntilFileAttached();
  WidgetsFlutterBinding.ensureInitialized();

  // Route uncaught Flutter framework and platform errors into the debug log
  // so crashes are diagnosable from the user-shared log (issue #318).
  installGlobalErrorHandlers();
  registerBundledLicenses();

  // Store videos from Google Drive and WebDAV stream through this worker
  // (issue #4162). Started now, not awaited, so it controls the page by
  // the time a video opens; the viewer waits for it if not.
  unawaited(startMediaStreamWorker());

  final prefs = await loadPreferences();
  applyStartupPreferences(prefs);

  final appSupportDir = await supportDirectory();
  final logFileService = await attachFileLogging(
    prefs,
    p.join(appSupportDir, 'logs'),
    logEnvironment: logEnvironment,
  );

  // Forget this device, a restore or a sample logbook switch in another tab
  // leaves this one holding the old library in memory; a reload drops it
  // (issue #4121).
  BrowserOriginStorage.onReloadAskedElsewhere(BrowserOriginStorage.reloadPage);

  final locationService = DatabaseLocationService(prefs);
  // A library a restore replaced while another tab held it (issue #4121).
  // Other names than the one about to open, so the two never meet.
  unawaited(sweepLibraries(locationService.webLibraryPath));
  run(
    buildStartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: locationService,
      // Demo mode keeps its state in local storage here (issue #4121).
      demoPaths: DemoPaths(appSupportDir),
    ),
  );
  // The smoke runner reads Flutter's semantics tree, which a page only
  // builds once a screen reader asks; `?a11y=1` asks from the first frame
  // (issue #4121).
  if ((queryParameters ?? Uri.base.queryParameters)['a11y'] == '1') {
    bootstrapSemanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
  }
}
