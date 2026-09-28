import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/app_directories.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';

/// Service for managing database file location
///
/// This service handles:
/// - Storing/retrieving storage configuration from SharedPreferences
/// - Resolving the actual database path based on configuration
/// - Platform-specific folder selection
/// - Verifying folder accessibility
/// The folder picker itself failed (as opposed to the user cancelling).
class FolderPickException implements Exception {
  final String message;
  const FolderPickException(this.message);

  @override
  String toString() => 'FolderPickException: $message';
}

/// Outcome of the startup accessibility check for a custom DB location.
///
/// No outcome changes the stored configuration. The check used to reset it on
/// macOS and iOS when the database could not be read, with nothing said on
/// screen, so the next launch opened an empty default database while the
/// diver's real one sat untouched in their folder (#2178). Going back to the
/// default location is now something only the diver can choose, from the
/// startup failure screen.
enum StartupLocationCheck {
  /// No custom location configured; nothing to check.
  defaultLocation,

  /// Custom database exists and is readable.
  accessible,

  /// The folder is configured but holds no database yet -- the normal
  /// first launch after choosing a location. The database is created at the
  /// chosen path.
  keptDatabaseMissing,

  /// The folder itself cannot be read: one the sandbox no longer grants, a
  /// permissions fault on the folder. The open surfaces a real error (#218).
  keptInaccessible,

  /// The folder can be read but the database in it cannot be opened: a
  /// permissions fault on the file, or something that is not a file at all.
  /// The folder is fine, so this is not [isUnreachable]; the failure screen
  /// keeps the routes that repair or replace the file.
  keptDatabaseUnreadable,

  /// The custom database is in iCloud but its contents are not on this
  /// device. Not [isUnreachable]: it is a fetch still to happen, which
  /// startup does under the splash instead of creating an empty dive log
  /// (#2177).
  keptNotDownloaded,

  /// The configured folder itself is not there: an unplugged drive, a share
  /// that is not mounted, a folder that was moved or deleted.
  keptFolderMissing;

  /// Whether the configured folder cannot be used as things stand.
  bool get isUnreachable =>
      this == StartupLocationCheck.keptInaccessible ||
      this == StartupLocationCheck.keptFolderMissing;
}

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
    return p.join(dbFolder.path, kAppDocumentsFolder, databaseFilename);
  }

  /// Get the default database directory
  Future<String> getDefaultDatabaseDirectory() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, kAppDocumentsFolder);
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
        windowsOptions: const WindowsOptions(lockParentWindow: true),
        linuxOptions: const LinuxOptions(lockParentWindow: true),
      );

      if (result == null) return null;
      return FolderPickResultWithBookmark(path: result);
    } catch (e, stackTrace) {
      // A thrown picker (e.g. a missing/broken XDG desktop portal on
      // Linux) must be distinguishable from a user cancel, or the setting
      // silently appears to do nothing (#218). Rethrow on the original
      // stack so logs point at the failing portal/DBus call.
      Error.throwWithStackTrace(FolderPickException('$e'), stackTrace);
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

  /// Stamps a custom location as one that has held a dive log, if nothing
  /// has stamped it yet (#2177).
  ///
  /// Called once a dive log has opened there. Every flow that saves a custom
  /// location stamps it today, but configurations saved before the stamp
  /// existed carry none, and without it a later loss reads as a first launch
  /// and an empty dive log is created in its place. This records a fact the
  /// app just observed; it changes no choice the diver made.
  Future<void> markCustomLocationVerified() async {
    final config = await getStorageConfig();
    if (!config.isCustomLocation || config.lastVerified != null) return;
    await saveStorageConfig(config.copyWith(lastVerified: DateTime.now()));
  }

  /// Restores access to a configured custom database location, then reports
  /// on it (#218).
  ///
  /// On bookmark platforms (macOS/iOS) the stored security-scoped bookmark is
  /// resolved first, because the sandbox drops folder access when the app
  /// quits. The diver's choice is KEPT whatever the check finds, on every
  /// platform: a folder that cannot be read right now is very often one that
  /// can be read later, and the failed open reports it on screen (#2178).
  /// A database iCloud holds but has not downloaded is left unread: that is a
  /// fetch still to happen, not lost access (#2177).
  Future<StartupLocationCheck> validateCustomLocationAtStartup({
    bool? isBookmarkPlatform,
  }) async {
    final bookmarkPlatform =
        isBookmarkPlatform ?? SecurityScopedBookmarkService.isSupported;
    final config = await restoreCustomLocationAccess(
      isBookmarkPlatform: bookmarkPlatform,
    );
    return _check(config, sandboxed: bookmarkPlatform);
  }

  /// The part of [validateCustomLocationAtStartup] that opening the database
  /// depends on: restores sandbox access through the stored bookmark and
  /// follows a folder the bookmark tracked to a new path. Returns the config
  /// in force afterwards. Reads nothing in the folder.
  ///
  /// Split out so startup can await just this before its first frame and
  /// leave the check, which only feeds a log line there, unawaited: on a dead
  /// network mount each of its file calls can block for the network timeout.
  Future<StorageConfig> restoreCustomLocationAccess({
    bool? isBookmarkPlatform,
  }) async {
    final bookmarkPlatform =
        isBookmarkPlatform ?? SecurityScopedBookmarkService.isSupported;
    final config = await getStorageConfig();
    if (!config.isCustomLocation || !bookmarkPlatform || !hasStoredBookmark()) {
      return config;
    }
    final resolved = await resolveStoredBookmark();
    return _followMovedFolder(config, resolved);
  }

  /// Points the config at the folder's new path when the bookmark followed a
  /// folder the diver moved or renamed.
  ///
  /// The same folder, not a new choice: a bookmark tracks its folder across a
  /// move, the stored path does not. Only a stored path that is GONE is
  /// replaced, and only by one that exists, so a folder still where the diver
  /// put it is never second-guessed.
  Future<StorageConfig> _followMovedFolder(
    StorageConfig config,
    String? resolved,
  ) async {
    final stored = config.customFolderPath;
    if (resolved == null || stored == null || p.equals(resolved, stored)) {
      return config;
    }
    if (await Directory(stored).exists() ||
        !await Directory(resolved).exists()) {
      return config;
    }
    debugPrint('Custom folder moved: $stored -> $resolved (from its bookmark)');
    final moved = config.copyWith(customFolderPath: resolved);
    await saveStorageConfig(moved);
    return moved;
  }

  /// Reports on a configured custom database location, changing nothing.
  ///
  /// Separate from [validateCustomLocationAtStartup] so the startup failure
  /// screen can ask again without resolving the bookmark a second time, which
  /// would start another security-scoped access that nothing stops.
  Future<StartupLocationCheck> checkCustomLocation() async =>
      _check(await getStorageConfig());

  Future<StartupLocationCheck> _check(
    StorageConfig config, {
    bool? sandboxed,
  }) async {
    final folder = config.customFolderPath;
    if (!config.isCustomLocation || folder == null) {
      return StartupLocationCheck.defaultLocation;
    }

    final dbPath = p.join(folder, databaseFilename);

    // A dive log iCloud has evicted is a fetch still to happen, not lost
    // access, so it is kept and left unread. Reading an evicted file would
    // fetch all of it before the read returned, with no limit and before the
    // app has drawn a frame. Startup fetches it instead, under the splash,
    // where it can say what is happening and give up (#2177).
    if (await isOnlyInICloud(dbPath)) {
      return StartupLocationCheck.keptNotDownloaded;
    }

    // Nothing at the path is NOT an access failure when the folder is there:
    // it is the first launch after choosing it (#218). Anything that DOES
    // occupy the path (including a directory) has to be opened to decide, so
    // test the entity type rather than File.exists().
    if (await FileSystemEntity.type(dbPath) == FileSystemEntityType.notFound) {
      if (!await Directory(folder).exists()) {
        return StartupLocationCheck.keptFolderMissing;
      }
      // A folder that cannot be entered hides its contents, so the database
      // reads as absent. That is lost access, not a first launch.
      return await _canList(folder)
          ? StartupLocationCheck.keptDatabaseMissing
          : StartupLocationCheck.keptInaccessible;
    }

    final error = await readProbeError(dbPath);
    if (error == null) return StartupLocationCheck.accessible;
    return unreadableVerdict(
      error,
      folderListable: await _canList(folder),
      sandboxed: sandboxed ?? SecurityScopedBookmarkService.isSupported,
    );
  }

  /// Decides whether a database that would not open is the FOLDER's fault.
  ///
  /// A folder that cannot be listed always is. But listing alone cannot
  /// decide it: a security-scoped folder can still be listed after the
  /// sandbox refuses its files (the headless guard in background_service.dart
  /// was written against exactly that). The refusal is the sandbox's
  /// signature instead: it denies a read with EPERM ("Operation not
  /// permitted"), where plain file permissions answer EACCES. So on a
  /// [sandboxed] platform EPERM blames the folder. Anything else in a folder
  /// that can be read is the file.
  @visibleForTesting
  static StartupLocationCheck unreadableVerdict(
    Object error, {
    required bool folderListable,
    required bool sandboxed,
  }) {
    if (!folderListable) return StartupLocationCheck.keptInaccessible;
    if (sandboxed &&
        error is FileSystemException &&
        error.osError?.errorCode == _ePerm) {
      return StartupLocationCheck.keptInaccessible;
    }
    return StartupLocationCheck.keptDatabaseUnreadable;
  }

  /// POSIX EPERM, which macOS and iOS share.
  static const int _ePerm = 1;

  /// Whether [folder]'s contents can be listed. Never throws.
  static Future<bool> _canList(String folder) async {
    try {
      await Directory(folder).list().isEmpty;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The configured custom folder, when it cannot be used as things stand.
  ///
  /// Null at the default location and whenever the folder is reachable, so a
  /// startup failure with some other cause is never blamed on the folder.
  Future<String?> unreachableCustomFolder() async {
    final config = await getStorageConfig();
    final check = await _check(config);
    return check.isUnreachable ? config.customFolderPath : null;
  }

  /// Clears the storage configuration, so the app goes back to its default
  /// location. Nothing at the custom location is moved or deleted.
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
  final dbDir = p.join(chosen.path, kAppDocumentsFolder);
  await Directory(dbDir).create(recursive: true);
  return dbDir;
}

/// Why [path] cannot be read, or null when it can.
///
/// Opens it and reads the first 16 bytes (the SQLite header), which is what
/// proves access: a sandboxed folder can be stat-ed and still refuse the
/// open. Shared by the foreground startup check and the headless background
/// guard so the two can never disagree about readability. Never throws.
Future<Object?> readProbeError(String path) async {
  RandomAccessFile? handle;
  try {
    handle = await File(path).open(mode: FileMode.read);
    await handle.read(16);
    return null;
  } catch (e) {
    return e;
  } finally {
    // Close even when the read throws, or the handle leaks on every launch
    // that hits a revoked-permission folder. Guarded, because an exception
    // raised in a finally block REPLACES the answer the try/catch settled on.
    try {
      await handle?.close();
    } catch (_) {
      // Nothing to do: the probe's answer is already decided.
    }
  }
}
