import 'dart:io';

/// Listing/head entry for a media store object.
class StoreObjectInfo {
  final String key;
  final int? sizeBytes;
  final DateTime lastModified;

  const StoreObjectInfo({
    required this.key,
    this.sizeBytes,
    required this.lastModified,
  });
}

/// Failure classification for retry policy and user surfacing
/// (design spec section 15).
enum MediaStoreErrorKind { notFound, auth, transient, fatal }

class MediaStoreException implements Exception {
  final String message;
  final MediaStoreErrorKind kind;
  final Object? cause;

  const MediaStoreException(this.message, {required this.kind, this.cause});

  @override
  String toString() => 'MediaStoreException(${kind.name}): $message';
}

/// Object storage for media bytes (design spec section 8.1).
///
/// Deliberately file-based, never whole-Uint8List in its contract, so the
/// interface survives Phase 3's multipart/streaming internals without
/// change and callers keep memory bounded for arbitrarily large media.
/// Keys are store-relative (see StoreKeys); adapters apply any
/// user-configured remote prefix.
abstract class MediaObjectStore {
  /// Object metadata, or null when [key] does not exist.
  Future<StoreObjectInfo?> head(String key);

  /// Uploads [source] to [key], overwriting any existing object.
  Future<void> putFile(String key, File source, {required String contentType});

  /// Downloads [key] into [destination]. Throws a [MediaStoreException]
  /// with [MediaStoreErrorKind.notFound] when the object is absent.
  Future<void> getFile(String key, File destination);

  /// Idempotent delete: absent keys succeed.
  Future<void> delete(String key);

  /// All objects whose key starts with [keyPrefix].
  Stream<StoreObjectInfo> list(String keyPrefix);
}
