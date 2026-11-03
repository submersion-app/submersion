import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/bootstrap/bootstrap_shared.dart';
import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_refresh_triggers.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/global_error_handler.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/windows_app_data_migration.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';

/// Starts the app on a native platform. The body is startup wiring that
/// never runs under test, so it is excluded from coverage.
// coverage:ignore-start
Future<void> bootstrapApp() async {
  // Hold log lines in memory until the log file is attached below, so a
  // failure in the startup steps before it is not lost (#1826).
  LoggerService.bufferUntilFileAttached();
  WidgetsFlutterBinding.ensureInitialized();

  // Route uncaught Flutter framework and platform errors into the debug log so
  // future crashes are diagnosable from the user-shared log (issue #318).
  installGlobalErrorHandlers(); // coverage:ignore-line

  registerBundledLicenses(); // coverage:ignore-line

  // Every HttpClient in the Dart VM (S3 sync, map tiles, NetworkImage,
  // weather, geocoding) goes through one hook. On Windows it supplies a
  // SecurityContext seeded from the OS certificate store, which Dart's
  // bundled BoringSSL cannot read; everywhere it routes each connection by
  // the current proxy snapshot (#3217). Must run before the first network
  // request; the snapshot stays direct until the saved choice loads below.
  // (Inside main(), so not reachable from the test host.)
  // coverage:ignore-start
  final proxyController = ProxyController(
    resolver: SystemProxyResolver.forPlatform(),
  );
  processProxyController = proxyController;
  HttpOverrides.global = AppHttpOverrides(
    currentProxy: () => proxyController.current,
  );
  // coverage:ignore-end

  // Relocate the Windows app-data trees off the legacy "Eric Griffin" company
  // directory. MUST precede SharedPreferences.getInstance(): on Windows
  // shared_preferences resolves its file through
  // PathProviderWindows.getApplicationSupportPath(), so reading prefs first
  // would strand the user's real settings under the old company name. Never
  // throws; the reports are logged once file logging is up.
  // (Windows-only and inside main(), so not reachable from the test host.)
  // coverage:ignore-start
  final appDataMigrations = await migrateWindowsAppDataDirectories();
  // coverage:ignore-end

  // Initialize SharedPreferences first (needed for storage config)
  final prefs = await SharedPreferences.getInstance();

  // The image-cache cap and the data-quality toggles, after prefs and before
  // the first frame; see [applyStartupPreferences].
  applyStartupPreferences(prefs); // coverage:ignore-line

  // Load the proxy choice and, in system mode, ask the OS (at most 3 s, so
  // a slow PAC server cannot hold up launch), then keep it current as the
  // network changes and the app resumes.
  // coverage:ignore-start
  await proxyController.initialize(ProxySettingsStore(prefs));
  ProxyRefreshTriggers(proxyController);
  // coverage:ignore-end

  // Attach the log file now that prefs and the app-support directory are
  // known; see [attachFileLogging] for why it is unconditional.
  final appSupportDir = await AppDirectories.support();
  final logFileService = await attachFileLogging(
    prefs,
    p.join(appSupportDir, 'logs'),
  );

  // Now that file logging is wired, report what the app-data migration did.
  // Anything other than "no legacy data" is worth a line in a shared log:
  // a failure here is the difference between a user's settings surviving an
  // upgrade and appearing to reset.
  // coverage:ignore-start
  const migrationLogger = LoggerService('AppDataMigration');
  for (final report in appDataMigrations) {
    if (report.outcome == AppDataMigrationOutcome.noLegacyData) continue;
    if (report.outcome == AppDataMigrationOutcome.failed) {
      migrationLogger.error('Windows app-data migration failed', error: report);
    } else {
      migrationLogger.info('Windows app-data migration: $report');
    }
  }
  // coverage:ignore-end

  // Create location service and get storage config
  final locationService = DatabaseLocationService(prefs);
  final storageConfig = await locationService.getStorageConfig();

  debugPrint('Storage config on startup:');
  debugPrint('  mode: ${storageConfig.mode}');
  debugPrint('  customFolderPath: ${storageConfig.customFolderPath}');

  // Restore access to a custom database location before anything opens it.
  // The diver's choice is kept on every platform even when the folder cannot
  // be reached (#218, #2178): the failed open lands on the startup failure
  // screen, which names the folder and offers the way back to the default
  // location. The check itself only feeds this log line, so it is not
  // awaited: on a dead network mount it could hold the first frame.
  await locationService.restoreCustomLocationAccess();
  unawaited(
    locationService.checkCustomLocation().then(
      (check) => debugPrint('  custom location check: $check'),
      onError: (Object e) => debugPrint('  custom location check failed: $e'),
    ),
  );

  // Launch the app immediately -- database init happens inside StartupWrapper
  // so the user sees a splash screen while initialization runs
  runApp(
    buildStartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: locationService,
      demoPaths: DemoPaths(appSupportDir),
    ),
  );
}
// coverage:ignore-end
