import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_refresh_triggers.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';
import 'package:submersion/core/services/global_error_handler.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/windows_app_data_migration.dart';

import 'package:submersion/app.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_attribution.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_detector_toggles.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/media/data/network_cache_config.dart';
import 'package:submersion/shared/services/incoming_share.dart';
import 'package:submersion/shared/services/navigation_ready_gate.dart';

// main() and the _bootstrap signature are untestable startup wiring (they
// never run under test); the zone-error logging is unit-tested via
// logUncaughtZoneError. Exclude only the wiring from coverage; the _bootstrap
// body below is covered normally.
// coverage:ignore-start
void main() {
  // Run startup inside a guarded zone so an uncaught async error during
  // initialization is logged instead of vanishing silently (issue #318
  // hardening: the app previously installed no global error capture at all).
  runZonedGuarded(_bootstrap, logUncaughtZoneError);
}

Future<void> _bootstrap() async {
  // coverage:ignore-end
  // Hold log lines in memory until the log file is attached below, so a
  // failure in the startup steps before it is not lost (#1826).
  LoggerService.bufferUntilFileAttached();
  WidgetsFlutterBinding.ensureInitialized();

  // Route uncaught Flutter framework and platform errors into the debug log so
  // future crashes are diagnosable from the user-shared log (issue #318).
  installGlobalErrorHandlers(); // coverage:ignore-line

  // The bundled ocean and sea table is CC-BY, so its credit has to reach
  // the license page whether or not anything ever geocodes a coordinate.
  SeaAreaService.registerLicense();
  // Likewise the CC BY bathymetry sources behind the seascape. The entry
  // itself is tested in bathymetry_attribution_test.dart.
  BathymetryAttribution.registerLicense(); // coverage:ignore-line

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
  _proxyController = proxyController;
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

  // Apply the global Flutter image-cache byte / object caps. The byte cap is
  // the diver's setting (issue #3337), hence after prefs. Must run after
  // `ensureInitialized()` (which constructs `PaintingBinding.instance`) and
  // before `runApp`, so the very first image decode honours it.
  // coverage:ignore-start
  applyMediaCacheCaps(
    memoryBytes: MediaCacheSettings.fromPrefs(prefs).memoryCacheBytes,
  );
  // coverage:ignore-end

  // Load the proxy choice and, in system mode, ask the OS (at most 3 s, so
  // a slow PAC server cannot hold up launch), then keep it current as the
  // network changes and the app resumes.
  // coverage:ignore-start
  await proxyController.initialize(ProxySettingsStore(prefs));
  ProxyRefreshTriggers(proxyController);
  // coverage:ignore-end

  // Hydrate the process-wide data-quality detector toggles from prefs so
  // fire-and-forget scans honor saved toggles before the settings page opens.
  QualityDetectorTogglesNotifier.hydrateFromPrefs(prefs);

  // Initialize the log file service and attach it unconditionally: warnings
  // and errors always reach the file, so a bug report can carry the failure
  // that prompted it (#1826). Debug mode only adds the verbose levels.
  final appSupportDir = await getApplicationSupportDirectory();
  final logFileService = LogFileService(
    logDirectory: '${appSupportDir.path}/logs',
  );
  await logFileService.initialize();

  final debugEnabled = prefs.getBool('debug_mode_enabled') ?? false;
  LoggerService.configureFileLogging(logFileService, verbose: debugEnabled);
  // Stamp the build and device at the top of the session so a log file that
  // spans several app versions attributes each run to the build that wrote
  // it (issue #1246). Not awaited: startup must not block on a platform
  // channel, and the write is serialized behind LoggerService's queue.
  unawaited(logSessionEnvironment());

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
    StartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: locationService,
    ),
  );
}

/// Global key notifier. Changing the value forces ProviderScope to rebuild,
/// disposing all providers and re-fetching from the current database.
final _restartKey = ValueNotifier<Key>(UniqueKey());

/// The share gate for the life of the process. A share still waiting for the
/// app to be able to open it (during setup, say) outlives the ProviderScope
/// that [restartApp] replaces, and the new app root opens it (#2690).
final _incomingShares = NavigationReadyGate<IncomingShare>();

/// The proxy snapshot holder for the life of the process, made in main()
/// before the first request. Null where main() did not run (tests), which
/// leaves the Network settings page's provider unconfigured.
ProxyController? _proxyController;

/// Trigger a soft restart by rebuilding the entire ProviderScope.
/// Call this after a database restore to refresh all cached data.
void restartApp() {
  _restartKey.value = UniqueKey();
}

class SubmersionRestart extends StatelessWidget {
  final SharedPreferences prefs;
  final LogFileService logFileService;

  const SubmersionRestart({
    super.key,
    required this.prefs,
    required this.logFileService,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Key>(
      valueListenable: _restartKey,
      builder: (context, key, _) {
        return ProviderScope(
          key: key,
          overrides: rootProviderOverrides(
            prefs: prefs,
            logFileService: logFileService,
            incomingShares: _incomingShares,
            proxyController: _proxyController,
          ).cast(),
          child: const SubmersionApp(),
        );
      },
    );
  }
}
