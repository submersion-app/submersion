import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';

/// Service for managing database file location
///
/// This service handles:
/// - Storing/retrieving storage configuration from SharedPreferences
/// - Resolving the actual database path based on configuration
/// - Platform-specific folder selection
/// - Verifying folder accessibility
class DatabaseLocationService {
  final SharedPreferences _prefs;

  // SharedPreferences keys
  static const _modeKey = 'db_storage_mode';
  static const _customPathKey = 'db_custom_path';
  static const _lastVerifiedKey = 'db_path_last_verified';
  static const _bookmarkDataKey = 'db_security_bookmark';

  // Database filename
  static const databaseFilename = 'submersion.db';

  DatabaseLocationService(this._prefs);

  /// UI hook to let the user choose among external volumes (Android). Set by the
  /// storage settings page; when null the first (internal) volume is used.
  Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)?
  _chooseExternalVolume;

  set externalVolumeChooser(
    Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)? chooser,
  ) => _chooseExternalVolume = chooser;

  /// Get the current storage configuration
  Future<StorageConfig> getStorageConfig() async {
    final modeString = _prefs.getString(_modeKey);
    final customPath = _prefs.getString(_customPathKey);
    final lastVerifiedMs = _prefs.getInt(_lastVerifiedKey);

    final mode = modeString == 'customFolder'
        ? StorageLocationMode.customFolder
        : StorageLocationMode.appDefault;

    return StorageConfig(
      mode: mode,
      customFolderPath: customPath,
      lastVerified: lastVerifiedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastVerifiedMs)
          : null,
    );
  }

  /// Save the storage configuration
  Future<void> saveStorageConfig(StorageConfig config) async {
    await _prefs.setString(
      _modeKey,
      config.mode == StorageLocationMode.customFolder
          ? 'customFolder'
          : 'appDefault',
    );

    if (config.customFolderPath != null) {
      await _prefs.setString(_customPathKey, config.customFolderPath!);
    } else {
      await _prefs.remove(_customPathKey);
    }

    if (config.lastVerified != null) {
      await _prefs.setInt(
        _lastVerifiedKey,
        config.lastVerified!.millisecondsSinceEpoch,
      );
    } else {
      await _prefs.remove(_lastVerifiedKey);
    }
  }

  /// Get the database file path based on current configuration
  Future<String> getDatabasePath() async {
    final config = await getStorageConfig();

    if (config.mode == StorageLocationMode.customFolder &&
        config.customFolderPath != null) {
      return p.join(config.customFolderPath!, databaseFilename);
    }

    return getDefaultDatabasePath();
  }

  /// Get the default database path (app documents directory)
  Future<String> getDefaultDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'Submersion', databaseFilename);
  }

  /// Get the default database directory
  Future<String> getDefaultDatabaseDirectory() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'Submersion');
  }

  /// Check if custom folder mode is supported on this platform
  ///
  /// Custom folder is supported on all platforms:
  /// - macOS: Full support with security-scoped bookmarks
  /// - iOS: Full support with security-scoped bookmarks for iCloud Drive
  /// - Windows/Linux: Full support with standard file system access
  /// - Android: app-specific external storage (internal or SD card). The live
  ///   DB needs a real lockable path; arbitrary SAF folders cannot back a
  ///   SQLite file, so the choice is curated to writable app-specific volumes.
  bool get isCustomFolderSupported => true;

  /// Check if we're running on a desktop platform
  bool get isDesktopPlatform =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Pick a custom folder for database storage
  ///
  /// On iOS, uses native picker to properly handle security-scoped URLs.
  /// On other platforms, uses file_picker plugin.
  ///
  /// Returns a [FolderPickResultWithBookmark] containing the path and optional
  /// bookmark data (iOS only), or null if cancelled.
  Future<FolderPickResultWithBookmark?> pickCustomFolder() async {
    // On iOS, use native picker to capture security-scoped URL
    if (Platform.isIOS) {
      try {
        final result =
            await SecurityScopedBookmarkService.pickFolderWithSecurityScope();
        if (result == null) return null;

        return FolderPickResultWithBookmark(
          path: result.path,
          bookmarkData: result.bookmarkData,
        );
      } catch (e) {
        debugPrint('iOS folder picker failed: $e');
        return null;
      }
    }

    // Android: the live DB needs a real lockable path (SQLite locking + WAL),
    // so SAF content URIs cannot back it. Offer the app-specific external
    // volumes (internal storage + SD card) from path_provider -- real writable
    // paths that need no permissions.
    // The native volume query + platform gate are untestable in the host VM;
    // the selection/cancel logic lives in the unit-tested [resolveAndroidDbDir].
    // coverage:ignore-start
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories();
      if (dirs == null || dirs.isEmpty) return null;
      final options = classifyExternalDirs(dirs.map((d) => d.path).toList());
      final dbDir = await resolveAndroidDbDir(options, _chooseExternalVolume);
      if (dbDir == null) return null;
      return FolderPickResultWithBookmark(path: dbDir);
    }
    // coverage:ignore-end

    // On other platforms (desktop), use file_picker
    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose Database Storage Location',
        lockParentWindow: true,
      );

      if (result == null) return null;
      return FolderPickResultWithBookmark(path: result);
    } catch (e) {
      // Handle any errors from file picker
      return null;
    }
  }

  /// Verify that a folder is accessible and writable
  ///
  /// On iOS, this uses security-scoped resource access via native code
  /// because standard Dart file operations don't work with iOS's
  /// security-scoped URLs from the document picker.
  Future<bool> verifyFolderAccessible(String folderPath) async {
    try {
      final dir = Directory(folderPath);

      // Check if directory exists
      if (!await dir.exists()) {
        return false;
      }

      // On iOS, use native security-scoped verification
      if (Platform.isIOS) {
        final result = await SecurityScopedBookmarkService.verifyWriteAccess(
          folderPath,
        );
        return result ?? false;
      }

      // On other platforms, try to create a test file to verify write access
      final testFile = File(p.join(folderPath, '.submersion_test'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if a database file exists at the given folder path
  Future<bool> databaseExistsAt(String folderPath) async {
    final dbPath = p.join(folderPath, databaseFilename);
    return File(dbPath).exists();
  }

  /// Update the last verified timestamp for the current config
  Future<void> updateLastVerified() async {
    final config = await getStorageConfig();
    await saveStorageConfig(config.copyWith(lastVerified: DateTime.now()));
  }

  /// Clear the storage configuration and reset to default
  Future<void> resetToDefault() async {
    // Stop accessing any security-scoped resource first
    await SecurityScopedBookmarkService.stopAccessingSecurityScopedResource();

    await _prefs.remove(_modeKey);
    await _prefs.remove(_customPathKey);
    await _prefs.remove(_lastVerifiedKey);
    await _prefs.remove(_bookmarkDataKey);
  }

  /// Creates and stores a security-scoped bookmark for the given folder path.
  ///
  /// On macOS, this allows the app to regain access to the folder after restart.
  /// On other platforms, this is a no-op.
  Future<bool> createAndStoreBookmark(String folderPath) async {
    if (!SecurityScopedBookmarkService.isSupported) {
      debugPrint('Security-scoped bookmarks not supported on this platform');
      return true; // Not an error on unsupported platforms
    }

    debugPrint('Creating security-scoped bookmark for: $folderPath');
    final bookmarkData = await SecurityScopedBookmarkService.createBookmark(
      folderPath,
    );

    if (bookmarkData == null) {
      debugPrint('Failed to create security-scoped bookmark');
      return false;
    }

    // Store bookmark as base64 in SharedPreferences
    final base64Data = base64Encode(bookmarkData);
    await _prefs.setString(_bookmarkDataKey, base64Data);
    debugPrint(
      'Security-scoped bookmark stored successfully (${bookmarkData.length} bytes)',
    );
    return true;
  }

  /// Resolves a stored security-scoped bookmark and starts accessing the resource.
  ///
  /// Returns the resolved path if successful, or null if:
  /// - No bookmark is stored
  /// - The bookmark is invalid or cannot be resolved
  /// - The platform doesn't support security-scoped bookmarks
  ///
  /// If the bookmark is stale, it will be logged but access may still work.
  Future<String?> resolveStoredBookmark() async {
    if (!SecurityScopedBookmarkService.isSupported) {
      return null;
    }

    final base64Data = _prefs.getString(_bookmarkDataKey);
    if (base64Data == null) {
      debugPrint('No stored security-scoped bookmark found');
      return null;
    }

    try {
      final bookmarkData = base64Decode(base64Data);
      debugPrint(
        'Resolving security-scoped bookmark (${bookmarkData.length} bytes)',
      );

      final result = await SecurityScopedBookmarkService.resolveBookmark(
        Uint8List.fromList(bookmarkData),
      );

      if (result == null) {
        debugPrint('Failed to resolve security-scoped bookmark');
        return null;
      }

      if (result.isStale) {
        debugPrint('Security-scoped bookmark is stale, may need recreation');
        // Note: Stale bookmarks often still work, so we continue
      }

      debugPrint('Security-scoped bookmark resolved to: ${result.path}');
      return result.path;
    } catch (e) {
      debugPrint('Error resolving security-scoped bookmark: $e');
      return null;
    }
  }

  /// Checks if we have a stored security-scoped bookmark
  bool hasStoredBookmark() {
    return _prefs.containsKey(_bookmarkDataKey);
  }

  /// Clears the stored security-scoped bookmark
  Future<void> clearStoredBookmark() async {
    await SecurityScopedBookmarkService.stopAccessingSecurityScopedResource();
    await _prefs.remove(_bookmarkDataKey);
  }
}

/// Result of picking a folder, with optional bookmark data for iOS.
class FolderPickResultWithBookmark {
  /// The folder path
  final String path;

  /// Bookmark data for persistent security-scoped access (iOS only).
  /// If provided, this should be stored and used to restore access after app restart.
  final Uint8List? bookmarkData;

  const FolderPickResultWithBookmark({required this.path, this.bookmarkData});
}

/// A selectable external volume for the database location (Android).
class ExternalVolumeOption {
  const ExternalVolumeOption({required this.path, required this.isInternal});

  final String path;

  /// True for the primary emulated/internal volume; false for removable (SD).
  final bool isInternal;
}

/// Classifies app-specific external dirs without native code: the primary
/// emulated volume is internal; any other volume is removable (SD card). The UI
/// maps [ExternalVolumeOption.isInternal] to a localized label.
List<ExternalVolumeOption> classifyExternalDirs(List<String> dirPaths) {
  final out = <ExternalVolumeOption>[];
  for (var i = 0; i < dirPaths.length; i++) {
    final path = dirPaths[i];
    final isInternal = i == 0 || path.contains('/storage/emulated/');
    out.add(ExternalVolumeOption(path: path, isInternal: isInternal));
  }
  return out;
}

/// Resolves and creates the database directory among [options] using [chooser]
/// (or the primary internal volume when no chooser is provided). Returns null
/// if the user dismissed the chooser.
///
/// Extracted from the Android branch of
/// [DatabaseLocationService.pickCustomFolder] so the selection + cancel logic
/// is unit-testable without a platform channel.
Future<String?> resolveAndroidDbDir(
  List<ExternalVolumeOption> options,
  Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)? chooser,
) async {
  final ExternalVolumeOption chosen;
  if (chooser != null) {
    final picked = await chooser(options);
    // A null result means the user dismissed the chooser -> cancel rather than
    // silently relocating to the first volume.
    if (picked == null) return null;
    chosen = picked;
  } else {
    // No chooser injected (e.g. background/headless flows): default to the
    // primary internal volume.
    chosen = options.first;
  }
  final dbDir = p.join(chosen.path, 'Submersion');
  await Directory(dbDir).create(recursive: true);
  return dbDir;
}
