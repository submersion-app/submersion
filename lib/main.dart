import 'dart:io';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/domain/entities/storage_config.dart';
import 'core/services/database_location_service.dart';
import 'core/services/database_service.dart';
import 'core/services/security_scoped_bookmark_service.dart';
import 'features/marine_life/data/repositories/species_repository.dart';
import 'features/settings/presentation/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences first (needed for storage config)
  final prefs = await SharedPreferences.getInstance();

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

  // Initialize database with location service
  await DatabaseService.instance.initialize(locationService: locationService);

  // Seed common species data
  final speciesRepository = SpeciesRepository();
  await speciesRepository.seedCommonSpecies();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SubmersionApp(),
    ),
  );
}
