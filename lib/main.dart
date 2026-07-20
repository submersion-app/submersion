import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/trusted_http_overrides.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/global_error_handler.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';

import 'package:submersion/app.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_detector_toggles.dart';
import 'package:submersion/features/media/data/network_cache_config.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
  WidgetsFlutterBinding.ensureInitialized();

  // Route uncaught Flutter framework and platform errors into the debug log so
  // future crashes are diagnosable from the user-shared log (issue #318).
  installGlobalErrorHandlers(); // coverage:ignore-line

  // Windows cannot expose its system trust store to Dart's bundled BoringSSL,
  // so every default-context HttpClient (S3 sync, map tiles, NetworkImage,
  // weather, geocoding) routes through a SecurityContext seeded from the OS
  // certificate store, with an embedded CA fallback. No-op on platforms whose
  // default trust already works. Must run before the first network request.
  // (Windows-only and inside main(), so not reachable from the test host.)
  // coverage:ignore-start
  if (Platform.isWindows) {
    HttpOverrides.global = TrustedHttpOverrides();
  }
  // coverage:ignore-end

  // Apply the global Flutter image-cache byte / object caps for cached
  // network media. Must run after `ensureInitialized()` (which constructs
  // `PaintingBinding.instance`) and before `runApp`, so the very first
  // image decode honours the 75 MB ceiling.
  applyMediaCacheCaps();

  // Initialize SharedPreferences first (needed for storage config)
  final prefs = await SharedPreferences.getInstance();

  // Hydrate the process-wide data-quality detector toggles from prefs so
  // fire-and-forget scans honor saved toggles before the settings page opens.
  QualityDetectorTogglesNotifier.hydrateFromPrefs(prefs);

  // Initialize log file service (always created so it's ready when needed)
  final appSupportDir = await getApplicationSupportDirectory();
  final logFileService = LogFileService(
    logDirectory: '${appSupportDir.path}/logs',
  );
  await logFileService.initialize();

  // Only enable file logging when debug mode is active
  final debugEnabled = prefs.getBool('debug_mode_enabled') ?? false;
  if (debugEnabled) {
    LoggerService.setFileService(logFileService);
  }

  // Create location service and get storage config
  final locationService = DatabaseLocationService(prefs);
  final storageConfig = await locationService.getStorageConfig();

  debugPrint('Storage config on startup:');
  debugPrint('  mode: ${storageConfig.mode}');
  debugPrint('  customFolderPath: ${storageConfig.customFolderPath}');

  // If using custom folder, we need to restore access via security-scoped bookmark
  // macOS sandbox revokes folder access after app restart - bookmarks restore it
  if (storageConfig.mode == StorageLocationMode.customFolder &&
      storageConfig.customFolderPath != null) {
    // Try to resolve the security-scoped bookmark to restore folder access
    if (SecurityScopedBookmarkService.isSupported &&
        locationService.hasStoredBookmark()) {
      debugPrint('  Resolving security-scoped bookmark...');
      final resolvedPath = await locationService.resolveStoredBookmark();

      if (resolvedPath != null) {
        debugPrint('  Bookmark resolved successfully: $resolvedPath');
      } else {
        debugPrint('  Failed to resolve bookmark - access may be blocked');
      }
    }

    // Verify the database is actually accessible after bookmark resolution
    final dbPath = await locationService.getDatabasePath();
    debugPrint('  database path: $dbPath');

    bool canAccess = false;
    try {
      final file = File(dbPath);
      if (await file.exists()) {
        // Try to read the first few bytes to verify actual access
        final raf = await file.open(mode: FileMode.read);
        await raf.read(16); // Read SQLite header
        await raf.close();
        canAccess = true;
        debugPrint('  database accessible: true');
      } else {
        debugPrint('  database file does not exist');
      }
    } catch (e) {
      debugPrint('  database accessible: false (error: $e)');
      canAccess = false;
    }

    if (!canAccess) {
      // Can't access database at custom location, reset to default
      debugPrint(
        '  WARNING: Resetting to default because database is not accessible',
      );
      await locationService.resetToDefault();
    }
  }

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
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            logFileServiceProvider.overrideWithValue(logFileService),
          ],
          child: const SubmersionApp(),
        );
      },
    );
  }
}
