import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of picking a backup folder on iOS: the chosen path plus a
/// persistable security-scoped bookmark for regaining access after restart.
@immutable
class BackupFolderPick {
  final String path;
  final Uint8List? bookmark;
  const BackupFolderPick({required this.path, this.bookmark});
}

/// A resolved, currently-armed security-scoped bookmark.
///
/// [ref] is a session-local handle that MUST be passed to
/// [BackupBookmarkService.release] when access is no longer needed, so the
/// native side can balance its `startAccessingSecurityScopedResource` call.
@immutable
class BackupBookmarkLease {
  final String ref;
  final String path;
  final bool isStale;
  const BackupBookmarkLease({
    required this.ref,
    required this.path,
    required this.isStale,
  });
}

/// Dart wrapper over the `app.submersion/backup_bookmark` channel.
///
/// Backups use a DEDICATED native handler, separate from the database-location
/// [SecurityScopedBookmarkHandler], so arming a backup-folder scope never
/// displaces the database scope. The native side keeps multiple concurrently
/// active scoped URLs keyed by [BackupBookmarkLease.ref].
///
/// Every method is a no-op on non-Apple platforms (callers keep using bare
/// paths there, which work without security scoping).
class BackupBookmarkService {
  static const _channel = MethodChannel('app.submersion/backup_bookmark');

  /// Test seam overriding the platform-support check. Production leaves null so
  /// the real `Platform` check is used. Mirrors
  /// `BackupFailedException.debugIsWindows`.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Whether security-scoped bookmarks are supported on this platform.
  static bool get isSupported =>
      debugSupportedOverride ?? (Platform.isIOS || Platform.isMacOS);

  /// Presents the native folder picker (iOS) and returns the picked path plus
  /// a security-scoped bookmark captured while access is still live. Returns
  /// null if the user cancelled or the platform is unsupported.
  static Future<BackupFolderPick?> pickFolder() async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'pickFolderWithSecurityScope',
      );
      if (result == null) return null;
      final path = result['path'] as String?;
      if (path == null) return null;
      return BackupFolderPick(
        path: path,
        bookmark: result['bookmarkData'] as Uint8List?,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Backup folder pick failed: ${e.message}');
      rethrow;
    }
  }

  /// Creates a security-scoped bookmark for [path]. Used on macOS where the
  /// folder is chosen via file_picker rather than the native picker. Returns
  /// null on failure or unsupported platforms.
  static Future<Uint8List?> createBookmark(String path) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('createBookmark', {
        'path': path,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Backup bookmark create failed: ${e.message}');
      return null;
    }
  }

  /// Resolves a stored bookmark, starts security-scoped access, and returns a
  /// [BackupBookmarkLease]. The caller must [release] the lease's ref when
  /// done. Returns null if the bookmark cannot be resolved or the platform is
  /// unsupported.
  static Future<BackupBookmarkLease?> resolveBookmark(Uint8List data) async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'resolveBookmark',
        {'bookmarkData': data},
      );
      if (result == null) return null;
      final ref = result['ref'] as String?;
      final path = result['path'] as String?;
      if (ref == null || path == null) return null;
      return BackupBookmarkLease(
        ref: ref,
        path: path,
        isStale: result['isStale'] as bool? ?? false,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Backup bookmark resolve failed: ${e.message}');
      return null;
    }
  }

  /// Stops security-scoped access for the resource held under [ref].
  static Future<void> release(String ref) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('releaseBookmark', {'ref': ref});
    } on MissingPluginException {
      // No native handler available; nothing to release.
    } on PlatformException catch (e) {
      debugPrint('Backup bookmark release failed: ${e.message}');
    }
  }

  /// Stops security-scoped access for every backup URL the native side holds.
  static Future<void> releaseAll() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('releaseAllBookmarks');
    } on MissingPluginException {
      // No native handler available; nothing to release.
    } on PlatformException catch (e) {
      debugPrint('Backup bookmark releaseAll failed: ${e.message}');
    }
  }

  /// Verifies write access to [path] using security-scoped access. Returns
  /// false on failure or unsupported platforms.
  static Future<bool> verifyWriteAccess(String path) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('verifyWriteAccess', {
        'path': path,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Backup bookmark verifyWriteAccess failed: ${e.message}');
      return false;
    }
  }
}
