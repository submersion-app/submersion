import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/storage_config.dart';
import 'security_scoped_bookmark_service.dart';

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
  /// Custom folder is supported on all platforms, but with limitations on mobile:
  /// - iOS: Limited to app sandbox + iCloud Drive documents
  /// - Android: Uses Storage Access Framework (SAF)
  bool get isCustomFolderSupported => true;

  /// Check if we're running on a desktop platform
  bool get isDesktopPlatform =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Pick a custom folder for database storage
  ///
  /// Returns the selected folder path, or null if cancelled
  Future<String?> pickCustomFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Database Storage Location',
        lockParentWindow: true,
      );

      return result;
    } catch (e) {
      // Handle any errors from file picker
      return null;
    }
  }

  /// Verify that a folder is accessible and writable
  Future<bool> verifyFolderAccessible(String folderPath) async {
    try {
      final dir = Directory(folderPath);

      // Check if directory exists
      if (!await dir.exists()) {
        return false;
      }

      // Try to create a test file to verify write access
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
    await saveStorageConfig(
      config.copyWith(lastVerified: DateTime.now()),
    );
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
    final bookmarkData = await SecurityScopedBookmarkService.createBookmark(folderPath);

    if (bookmarkData == null) {
      debugPrint('Failed to create security-scoped bookmark');
      return false;
    }

    // Store bookmark as base64 in SharedPreferences
    final base64Data = base64Encode(bookmarkData);
    await _prefs.setString(_bookmarkDataKey, base64Data);
    debugPrint('Security-scoped bookmark stored successfully (${bookmarkData.length} bytes)');
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
      debugPrint('Resolving security-scoped bookmark (${bookmarkData.length} bytes)');

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
