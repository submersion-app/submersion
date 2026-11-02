import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_attribution.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_detector_toggles.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/media/data/network_cache_config.dart';

/// The proxy snapshot holder for the life of the process, made by the native
/// bootstrap before the first request. Null where the bootstrap did not run
/// (tests) and in a browser, which has no proxy controller of its own; both
/// leave the Network settings page's provider unconfigured.
ProxyController? processProxyController;

/// Registers the licenses of the bundled data sets.
///
/// The ocean and sea table is CC-BY, so its credit has to reach the license
/// page whether or not anything ever geocodes a coordinate; likewise the
/// CC BY bathymetry sources behind the seascape.
void registerBundledLicenses() {
  SeaAreaService.registerLicense();
  BathymetryAttribution.registerLicense();
}

/// Applies the preferences that must be in force before the first frame.
///
/// The global image-cache byte cap is the diver's setting (issue #3337), and
/// the data-quality detector toggles are read here so fire-and-forget scans
/// honour saved toggles before the settings page opens. Must run after
/// `WidgetsFlutterBinding.ensureInitialized()` (which constructs
/// `PaintingBinding.instance`) and before `runApp`, so the very first image
/// decode honours the cap.
void applyStartupPreferences(SharedPreferences prefs) {
  applyMediaCacheCaps(
    memoryBytes: MediaCacheSettings.fromPrefs(prefs).memoryCacheBytes,
  );
  QualityDetectorTogglesNotifier.hydrateFromPrefs(prefs);
}

/// Creates the log file service under [logDirectory] and attaches it
/// unconditionally: warnings and errors always reach the file, so a bug
/// report can carry the failure that prompted it (#1826). Debug mode only
/// adds the verbose levels.
///
/// [logEnvironment] stamps the build and device at the top of the session so
/// a log file that spans several app versions attributes each run to the
/// build that wrote it (issue #1246). Not awaited: startup must not block on
/// a platform channel, and the write is serialized behind LoggerService's
/// queue.
Future<LogFileService> attachFileLogging(
  SharedPreferences prefs,
  String logDirectory, {
  Future<void> Function() logEnvironment = logSessionEnvironment,
}) async {
  final logFileService = LogFileService(logDirectory: logDirectory);
  await logFileService.initialize();

  final debugEnabled = prefs.getBool('debug_mode_enabled') ?? false;
  LoggerService.configureFileLogging(logFileService, verbose: debugEnabled);
  unawaited(logEnvironment());
  return logFileService;
}

/// The widget `runApp` receives: the splash screen that opens the database
/// and dissolves into the app once it is ready.
Widget buildStartupWrapper({
  required SharedPreferences prefs,
  required LogFileService logFileService,
  required DatabaseLocationService locationService,
  required DemoPaths? demoPaths,
}) => StartupWrapper(
  prefs: prefs,
  logFileService: logFileService,
  locationService: locationService,
  demoPaths: demoPaths,
);
