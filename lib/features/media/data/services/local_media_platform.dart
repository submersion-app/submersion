import 'dart:io';

import 'package:flutter/services.dart';

/// Result of a successful bookmark resolution. The [bookmarkRef] is a
/// session-local key that callers must pass to [LocalMediaPlatform.releaseBookmark]
/// when done reading the file.
class ResolvedBookmark {
  final String bookmarkRef;
  final String filePath;
  final bool stale;

  const ResolvedBookmark({
    required this.bookmarkRef,
    required this.filePath,
    required this.stale,
  });
}

/// Dart wrapper around the platform-channel for security-scoped bookmarks
/// (iOS / macOS) and persistable URI permissions (Android).
///
/// Used by Phase 2's `LocalFileResolver` to round-trip filesystem media
/// references that would otherwise become inaccessible after the app
/// relaunches (iOS sandbox) or the user revokes permissions (Android).
class LocalMediaPlatform {
  static const _channel = MethodChannel('com.submersion.app/local_media');

  /// iOS / macOS only. Creates a security-scoped bookmark for [filePath]
  /// and returns the raw bookmark blob. Callers store this in the keychain
  /// (via flutter_secure_storage) and pass it back to [resolveBookmark]
  /// when they need to read the file.
  Future<Uint8List> createBookmark(String filePath) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError('createBookmark is only supported on iOS / macOS');
    }
    // coverage:ignore-start
    final result = await _channel.invokeMethod<Uint8List>('createBookmark', {
      'filePath': filePath,
    });
    if (result == null) {
      throw StateError('createBookmark returned null');
    }
    return result;
    // coverage:ignore-end
  }

  /// iOS / macOS only. Starts security-scoped resource access for the given
  /// bookmark blob and returns a [ResolvedBookmark] containing the session
  /// ref + the resolved file path. Callers MUST invoke [releaseBookmark]
  /// when done.
  Future<ResolvedBookmark> resolveBookmark(Uint8List blob) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError(
        'resolveBookmark is only supported on iOS / macOS',
      );
    }
    // coverage:ignore-start
    final r = await _channel.invokeMapMethod<String, dynamic>(
      'resolveBookmark',
      {'bookmarkBlob': blob},
    );
    if (r == null) throw StateError('resolveBookmark returned null');
    return ResolvedBookmark(
      bookmarkRef: r['bookmarkRef'] as String,
      filePath: r['filePath'] as String,
      stale: (r['stale'] as bool?) ?? false,
    );
    // coverage:ignore-end
  }

  /// Releases the security-scoped resource access started by [resolveBookmark].
  /// Safe to call on any platform; no-ops on Android.
  Future<void> releaseBookmark(String bookmarkRef) async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    // coverage:ignore-start
    await _channel.invokeMethod<void>('releaseBookmark', {
      'bookmarkRef': bookmarkRef,
    });
    // coverage:ignore-end
  }

  /// iOS / macOS only. Releases every security-scoped URL the native handler
  /// is currently holding. Use on logout / app-teardown flows so dangling
  /// `startAccessingSecurityScopedResource()` calls don't leak for the rest
  /// of the process lifetime.
  Future<void> releaseAllBookmarks() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    // coverage:ignore-line
    await _channel.invokeMethod<void>('releaseAllBookmarks');
  }

  /// Android only. Calls `ContentResolver.takePersistableUriPermission` and
  /// returns the URI string itself (which becomes the bookmarkRef stored in
  /// the [MediaItem.bookmarkRef] column).
  Future<String> takePersistableUri(String uri) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('takePersistableUri is only supported on Android');
    }
    // coverage:ignore-start
    final r = await _channel.invokeMethod<String>('takePersistableUri', {
      'uri': uri,
    });
    if (r == null) throw StateError('takePersistableUri returned null');
    return r;
    // coverage:ignore-end
  }

  /// Android only. Releases a previously persistable URI permission.
  Future<void> releasePersistableUri(String uri) async {
    if (!Platform.isAndroid) return;
    // coverage:ignore-start
    await _channel.invokeMethod<void>(
      'releaseBookmark', // Android-side handler reuses this method name
      {'bookmarkRef': uri},
    );
    // coverage:ignore-end
  }

  /// Android only. Lists all persisted URI permissions (used by the Settings
  /// page to show the user's URI budget — Android caps at 128 per app).
  Future<List<String>> listPersistedUris() async {
    if (!Platform.isAndroid) return const [];
    // coverage:ignore-start
    final r = await _channel.invokeListMethod<String>('listPersistedUris');
    return r ?? const [];
    // coverage:ignore-end
  }

  /// iOS / macOS only. Reads the bytes of a previously-stored bookmark.
  ///
  /// [bookmarkBlob] is the raw bookmark data — callers retrieve it from
  /// `LocalBookmarkStorage`. The native side resolves the bookmark, starts
  /// security-scoped resource access, reads the file, releases access, and
  /// returns the bytes.
  ///
  /// On Android use [readUriBytes] instead — Android URIs don't go through
  /// the bookmark API.
  Future<Uint8List> readBookmarkBytes(Uint8List bookmarkBlob) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      // coverage:ignore-start
      // UnsupportedError throw — exercised by
      // local_media_platform_linux_test.dart on Linux CI hosts; on the
      // macOS dev host this branch is unreachable.
      throw UnsupportedError(
        'readBookmarkBytes is only supported on iOS / macOS',
      );
      // coverage:ignore-end
    }
    // coverage:ignore-start
    final result = await _channel.invokeMethod<Uint8List>('readBookmarkBytes', {
      'bookmarkBlob': bookmarkBlob,
    });
    if (result == null) throw StateError('readBookmarkBytes returned null');
    return result;
    // coverage:ignore-end
  }

  /// Android only. Reads the bytes of a persisted content URI via
  /// `ContentResolver.openInputStream`.
  ///
  /// On iOS / macOS use [readBookmarkBytes] instead — those platforms use
  /// the security-scoped bookmark API.
  Future<Uint8List> readUriBytes(String uri) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('readUriBytes is only supported on Android');
    }
    // coverage:ignore-start
    final result = await _channel.invokeMethod<Uint8List>('readUriBytes', {
      'uri': uri,
    });
    if (result == null) throw StateError('readUriBytes returned null');
    return result;
    // coverage:ignore-end
  }
}
