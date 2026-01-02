import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for managing security-scoped bookmarks on macOS and iOS.
///
/// Security-scoped bookmarks allow sandboxed apps to persist access
/// to user-selected folders across app restarts. Without these bookmarks,
/// the sandbox revokes folder access when the app quits.
///
/// On iOS, this is essential for accessing iCloud Drive folders or other
/// document provider locations that the user has selected.
///
/// This service is a no-op on non-Apple platforms.
class SecurityScopedBookmarkService {
  static const _channel = MethodChannel('app.submersion/security_scoped_bookmark');

  /// Whether security-scoped bookmarks are supported on this platform
  static bool get isSupported => Platform.isMacOS || Platform.isIOS;

  /// Creates a security-scoped bookmark for the given folder path.
  ///
  /// Returns the bookmark data as bytes that can be stored persistently.
  /// Returns null if bookmark creation fails or platform is not supported.
  static Future<Uint8List?> createBookmark(String path) async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'createBookmark',
        {'path': path},
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to create bookmark: ${e.message}');
      return null;
    }
  }

  /// Resolves a security-scoped bookmark and returns the path.
  ///
  /// This also starts accessing the security-scoped resource automatically.
  /// Returns a [BookmarkResolveResult] with the path and stale status,
  /// or null if resolution fails.
  ///
  /// If the bookmark is stale (folder was moved/renamed), a new bookmark
  /// should be created after the user reselects the folder.
  static Future<BookmarkResolveResult?> resolveBookmark(Uint8List bookmarkData) async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<Map>(
        'resolveBookmark',
        {'bookmarkData': bookmarkData},
      );

      if (result == null) return null;

      return BookmarkResolveResult(
        path: result['path'] as String,
        isStale: result['isStale'] as bool? ?? false,
      );
    } on PlatformException catch (e) {
      debugPrint('Failed to resolve bookmark: ${e.message}');
      return null;
    }
  }

  /// Manually starts accessing a security-scoped resource.
  ///
  /// This is typically called automatically by [resolveBookmark], but can
  /// be used if you need to start access separately.
  /// Returns true if access was granted.
  static Future<bool> startAccessingSecurityScopedResource(String path) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'startAccessingSecurityScopedResource',
        {'path': path},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to start accessing resource: ${e.message}');
      return false;
    }
  }

  /// Stops accessing the currently active security-scoped resource.
  ///
  /// Call this when you no longer need access to the resource.
  /// On macOS/iOS, there's a system limit on active security-scoped resources.
  static Future<void> stopAccessingSecurityScopedResource() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod<void>('stopAccessingSecurityScopedResource');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop accessing resource: ${e.message}');
    }
  }

  /// Verifies write access to a folder using security-scoped resource access.
  ///
  /// This is specifically for iOS where standard Dart file operations don't work
  /// with security-scoped URLs. The native code starts security-scoped access,
  /// attempts to write a test file, and cleans up.
  ///
  /// Returns true if write access is verified, false otherwise.
  /// On non-iOS platforms, returns null (caller should use standard file check).
  static Future<bool?> verifyWriteAccess(String path) async {
    // This method is only needed on iOS
    if (!Platform.isIOS) return null;

    try {
      final result = await _channel.invokeMethod<bool>(
        'verifyWriteAccess',
        {'path': path},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to verify write access: ${e.message}');
      return false;
    }
  }

  /// Picks a folder on iOS using native UIDocumentPicker and immediately
  /// captures the security-scoped URL, creates a bookmark, and verifies access.
  ///
  /// This is required on iOS because file_picker returns a path string that
  /// loses the security scope. By handling the picker natively, we can:
  /// 1. Capture the security-scoped URL directly
  /// 2. Immediately call startAccessingSecurityScopedResource()
  /// 3. Create a bookmark while we have access
  /// 4. Verify write permissions
  ///
  /// Returns a [FolderPickResult] with path and bookmark data, or null if cancelled.
  /// Only works on iOS - returns null on other platforms.
  static Future<FolderPickResult?> pickFolderWithSecurityScope() async {
    if (!Platform.isIOS) return null;

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'pickFolderWithSecurityScope',
      );

      if (result == null) return null;

      final path = result['path'] as String?;
      final bookmarkData = result['bookmarkData'] as Uint8List?;

      if (path == null) return null;

      return FolderPickResult(
        path: path,
        bookmarkData: bookmarkData,
      );
    } on PlatformException catch (e) {
      debugPrint('Failed to pick folder: ${e.message}');
      rethrow;
    }
  }
}

/// Result of picking a folder with security scope on iOS.
class FolderPickResult {
  /// The folder path
  final String path;

  /// The bookmark data for persistent access (iOS only)
  final Uint8List? bookmarkData;

  const FolderPickResult({
    required this.path,
    this.bookmarkData,
  });
}

/// Result of resolving a security-scoped bookmark.
class BookmarkResolveResult {
  /// The resolved file path
  final String path;

  /// Whether the bookmark is stale and needs to be recreated.
  ///
  /// A bookmark becomes stale if the folder was moved, renamed, or
  /// if system conditions have changed. When stale, the path may still
  /// be valid, but a new bookmark should be created for future use.
  final bool isStale;

  const BookmarkResolveResult({
    required this.path,
    required this.isStale,
  });

  @override
  String toString() => 'BookmarkResolveResult(path: $path, isStale: $isStale)';
}
