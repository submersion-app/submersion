import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for managing security-scoped bookmarks on macOS.
///
/// Security-scoped bookmarks allow a sandboxed macOS app to persist access
/// to user-selected folders across app restarts. Without these bookmarks,
/// the sandbox revokes folder access when the app quits.
///
/// This service is a no-op on non-macOS platforms.
class SecurityScopedBookmarkService {
  static const _channel = MethodChannel('app.submersion/security_scoped_bookmark');

  /// Whether security-scoped bookmarks are supported on this platform
  static bool get isSupported => Platform.isMacOS;

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
  /// On macOS, there's a system limit on active security-scoped resources.
  static Future<void> stopAccessingSecurityScopedResource() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod<void>('stopAccessingSecurityScopedResource');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop accessing resource: ${e.message}');
    }
  }
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
