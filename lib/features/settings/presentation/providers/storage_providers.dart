import 'dart:io';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_migration_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Platform capabilities for storage options
class StoragePlatformCapabilities {
  /// Whether custom folder selection is supported
  final bool supportsCustomFolder;

  /// Whether iCloud sync is supported (iOS/macOS only)
  final bool supportsICloud;

  /// Whether Google Drive sync is supported: everywhere except a
  /// Windows/Linux build with no Desktop-app OAuth client compiled in
  final bool supportsGoogleDrive;

  /// Whether this is a desktop platform
  final bool isDesktop;

  /// Whether "custom folder" can only mean an app-specific device volume
  /// (internal storage or SD card) rather than any folder the user names.
  ///
  /// True on Android: a live SQLite file needs a real lockable path for its
  /// `-wal`/`-shm` byte-range locks, which a Storage Access Framework stream
  /// cannot provide, so the picker offers app-specific external volumes
  /// instead of an arbitrary folder. The UI must not promise cloud-synced
  /// folders there (#311).
  final bool customFolderIsDeviceVolumeOnly;

  const StoragePlatformCapabilities({
    required this.supportsCustomFolder,
    required this.supportsICloud,
    required this.supportsGoogleDrive,
    required this.isDesktop,
    required this.customFolderIsDeviceVolumeOnly,
  });
}

/// Platform capabilities provider
final storagePlatformCapabilitiesProvider =
    Provider<StoragePlatformCapabilities>((ref) {
      return StoragePlatformCapabilities(
        // Custom folder is supported on all platforms:
        // - macOS: Uses security-scoped bookmarks for persistent access
        // - iOS: Uses security-scoped bookmarks for iCloud Drive folders
        // - Windows/Linux: Standard file system access
        // - Android: app-specific external volumes only (internal/SD card);
        //   scoped storage rules out an arbitrary folder for the live DB
        supportsCustomFolder: true,
        supportsICloud: Platform.isIOS || Platform.isMacOS,
        // Single source of truth shared with
        // GoogleDriveStorageProvider.isAvailable(), so the two cannot
        // diverge: compile-time OAuth config on mobile/macOS, and on
        // Windows/Linux the Desktop-app client being compiled in.
        supportsGoogleDrive: GoogleDriveClientConfig.isSupportedOnThisPlatform,
        isDesktop: Platform.isMacOS || Platform.isWindows || Platform.isLinux,
        customFolderIsDeviceVolumeOnly: Platform.isAndroid,
      );
    });

/// Database location service provider
final databaseLocationServiceProvider = Provider<DatabaseLocationService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DatabaseLocationService(prefs);
});

/// Database migration service provider
final databaseMigrationServiceProvider = Provider<DatabaseMigrationService>((
  ref,
) {
  final locationService = ref.watch(databaseLocationServiceProvider);
  return DatabaseMigrationService(DatabaseService.instance, locationService);
});

/// Current storage configuration provider
final storageConfigProvider = FutureProvider<StorageConfig>((ref) async {
  final locationService = ref.watch(databaseLocationServiceProvider);
  return locationService.getStorageConfig();
});

/// Storage configuration state for mutations
class StorageConfigState {
  final StorageConfig config;
  final bool isLoading;
  final bool isMigrating;
  final String? error;
  final MigrationResult? lastMigrationResult;

  const StorageConfigState({
    required this.config,
    this.isLoading = false,
    this.isMigrating = false,
    this.error,
    this.lastMigrationResult,
  });

  StorageConfigState copyWith({
    StorageConfig? config,
    bool? isLoading,
    bool? isMigrating,
    String? error,
    MigrationResult? lastMigrationResult,
    bool clearError = false,
    bool clearMigrationResult = false,
  }) {
    return StorageConfigState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isMigrating: isMigrating ?? this.isMigrating,
      error: clearError ? null : (error ?? this.error),
      lastMigrationResult: clearMigrationResult
          ? null
          : (lastMigrationResult ?? this.lastMigrationResult),
    );
  }
}

/// Storage configuration notifier for managing storage settings
class StorageConfigNotifier extends StateNotifier<StorageConfigState> {
  final DatabaseLocationService _locationService;
  final DatabaseMigrationService _migrationService;

  StorageConfigNotifier(this._locationService, this._migrationService)
    : super(
        const StorageConfigState(config: StorageConfig(), isLoading: true),
      ) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final config = await _locationService.getStorageConfig();
      state = state.copyWith(config: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load storage configuration: $e',
      );
    }
  }

  /// Reload the configuration
  Future<void> refresh() async {
    await _loadConfig();
  }

  /// Pick a custom folder for database storage
  ///
  /// Returns a [FolderPickResultWithBookmark] containing the path and optional
  /// bookmark data (for iOS), or null if cancelled.
  Future<FolderPickResultWithBookmark?> pickCustomFolder({
    Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)? chooser,
  }) async {
    _locationService.externalVolumeChooser = chooser;
    try {
      return await _locationService.pickCustomFolder();
    } finally {
      // Don't let the service retain a UI closure (which captures the page)
      // beyond this call.
      _locationService.externalVolumeChooser = null;
    }
  }

  /// Check for existing database at a folder
  Future<ExistingDatabaseInfo?> checkForExistingDatabase(
    String folderPath,
  ) async {
    return _migrationService.checkForExistingDatabase(folderPath);
  }

  /// Get info about the current database
  Future<ExistingDatabaseInfo?> getCurrentDatabaseInfo() async {
    return _migrationService.getCurrentDatabaseInfo();
  }

  /// Migrate database to a custom folder
  Future<MigrationResult> migrateToCustomFolder(String folderPath) async {
    state = state.copyWith(isMigrating: true, clearError: true);

    try {
      final result = await _migrationService.migrateToCustomFolder(folderPath);

      if (result.success) {
        // Reload config after successful migration
        final newConfig = await _locationService.getStorageConfig();
        state = state.copyWith(
          config: newConfig,
          isMigrating: false,
          lastMigrationResult: result,
        );
        // NOTE: Don't invalidate providers here - it causes a deadlock
        // The UI will invalidate after the dialog is dismissed
      } else {
        state = state.copyWith(
          isMigrating: false,
          error: result.errorMessage,
          lastMigrationResult: result,
        );
      }

      return result;
    } catch (e) {
      final result = MigrationResult.failure('Migration failed: $e');
      state = state.copyWith(
        isMigrating: false,
        error: result.errorMessage,
        lastMigrationResult: result,
      );
      return result;
    }
  }

  /// Migrate database back to the default location
  Future<MigrationResult> migrateToDefault() async {
    state = state.copyWith(isMigrating: true, clearError: true);

    try {
      final result = await _migrationService.migrateToDefault();

      if (result.success) {
        final newConfig = await _locationService.getStorageConfig();
        state = state.copyWith(
          config: newConfig,
          isMigrating: false,
          lastMigrationResult: result,
        );
        // NOTE: Don't invalidate providers here - it causes a deadlock
        // The UI will invalidate after the dialog is dismissed
      } else {
        state = state.copyWith(
          isMigrating: false,
          error: result.errorMessage,
          lastMigrationResult: result,
        );
      }

      return result;
    } catch (e) {
      final result = MigrationResult.failure('Migration failed: $e');
      state = state.copyWith(
        isMigrating: false,
        error: result.errorMessage,
        lastMigrationResult: result,
      );
      return result;
    }
  }

  /// Switch to using an existing database at the specified folder
  Future<MigrationResult> switchToExistingDatabase(String folderPath) async {
    state = state.copyWith(isMigrating: true, clearError: true);

    try {
      final result = await _migrationService.switchToExistingDatabase(
        folderPath,
      );

      if (result.success) {
        final newConfig = await _locationService.getStorageConfig();
        state = state.copyWith(
          config: newConfig,
          isMigrating: false,
          lastMigrationResult: result,
        );
        // NOTE: Don't invalidate providers here - it causes a deadlock
        // The UI will invalidate after the dialog is dismissed
      } else {
        state = state.copyWith(
          isMigrating: false,
          error: result.errorMessage,
          lastMigrationResult: result,
        );
      }

      return result;
    } catch (e) {
      final result = MigrationResult.failure('Switch failed: $e');
      state = state.copyWith(
        isMigrating: false,
        error: result.errorMessage,
        lastMigrationResult: result,
      );
      return result;
    }
  }

  /// Replace an existing database with the current database
  Future<MigrationResult> replaceExistingDatabase(String folderPath) async {
    state = state.copyWith(isMigrating: true, clearError: true);

    try {
      final result = await _migrationService.replaceExistingDatabase(
        folderPath,
      );

      if (result.success) {
        final newConfig = await _locationService.getStorageConfig();
        state = state.copyWith(
          config: newConfig,
          isMigrating: false,
          lastMigrationResult: result,
        );
        // NOTE: Don't invalidate providers here - it causes a deadlock
        // The UI will invalidate after the dialog is dismissed
      } else {
        state = state.copyWith(
          isMigrating: false,
          error: result.errorMessage,
          lastMigrationResult: result,
        );
      }

      return result;
    } catch (e) {
      final result = MigrationResult.failure('Replace failed: $e');
      state = state.copyWith(
        isMigrating: false,
        error: result.errorMessage,
        lastMigrationResult: result,
      );
      return result;
    }
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear the last migration result
  void clearMigrationResult() {
    state = state.copyWith(clearMigrationResult: true);
  }
}

/// Storage configuration notifier provider
final storageConfigNotifierProvider =
    StateNotifierProvider<StorageConfigNotifier, StorageConfigState>((ref) {
      final locationService = ref.watch(databaseLocationServiceProvider);
      final migrationService = ref.watch(databaseMigrationServiceProvider);
      return StorageConfigNotifier(locationService, migrationService);
    });

/// Current database path provider
final currentDatabasePathProvider = FutureProvider<String>((ref) async {
  final locationService = ref.watch(databaseLocationServiceProvider);
  return locationService.getDatabasePath();
});

/// Whether the current storage mode is custom folder
final isCustomFolderModeProvider = Provider<bool>((ref) {
  final configState = ref.watch(storageConfigNotifierProvider);
  return configState.config.mode == StorageLocationMode.customFolder;
});
