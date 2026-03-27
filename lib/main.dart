import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';

import 'package:submersion/app.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences first (needed for storage config)
  final prefs = await SharedPreferences.getInstance();

  // Initialize log file service for persistent logging
  final appSupportDir = await getApplicationSupportDirectory();
  final logFileService = LogFileService(
    logDirectory: '${appSupportDir.path}/logs',
  );
  await logFileService.initialize();
  LoggerService.setFileService(logFileService);

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

  try {
    // Initialize database with location service
    await DatabaseService.instance.initialize(locationService: locationService);

    // Initialize local-only cache database (device-specific, never synced)
    await LocalCacheDatabaseService.instance.initialize();

    // Initialize notification service
    await NotificationService.instance.initialize();

    // Initialize background service for periodic notification refresh
    await initializeBackgroundService();

    // Initialize tile cache for offline maps (non-blocking - app works without it)
    try {
      await TileCacheService.instance.initialize();
      debugPrint('Tile cache initialized successfully');
    } catch (e) {
      debugPrint('Warning: Tile cache initialization failed: $e');
      // App continues without offline map caching
    }

    // Seed built-in species from bundled JSON asset
    final speciesRepository = SpeciesRepository();
    await speciesRepository.seedBuiltInSpecies();

    runApp(SubmersionRestart(prefs: prefs));
  } on DatabaseVersionMismatchException catch (e) {
    debugPrint('FATAL: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.update, size: 64, color: Colors.orange),
                  const SizedBox(height: 24),
                  const Text(
                    'Update Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your dive data was saved by a newer version of '
                    'Submersion (schema v${e.databaseVersion}). This version '
                    'only supports up to schema v${e.appVersion}.',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please update Submersion to the latest version. '
                    'Your data is safe and has not been modified.',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  } catch (e, stack) {
    debugPrint('FATAL: App initialization failed: $e');
    debugPrint('$stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'Submersion failed to start',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$e',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Try restarting the app. If this persists, '
                    'reinstall or contact support.',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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

  const SubmersionRestart({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Key>(
      valueListenable: _restartKey,
      builder: (context, key, _) {
        return ProviderScope(
          key: key,
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const SubmersionApp(),
        );
      },
    );
  }
}
