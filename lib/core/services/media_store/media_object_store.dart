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
  String toString() {
    final base = 'MediaStoreException(${kind.name}): $message';
    final detail = _describe(cause);
    // The queue stores this string in errorMessage, and the Transfers page
    // and the media health report both read it, so the provider's own
    // explanation has to be in it: Dropbox puts its error_summary in the
    // cause, the S3 and Dropbox stores put the whole underlying
    // CloudStorageException there, and every adapter puts the
    // FileSystemException there on a read failure. #2018 was this same gap
    // one layer up, on Drive.
    //
    // Bounded, because a cause can be an HTML error page from a proxy and
    // this lands in a database column and a list tile. Skipped when the
    // message already contains it, which happens wherever a mapper folded
    // the cause's text in before wrapping it.
    if (detail == null || detail.isEmpty || _messageCarries(message, detail)) {
      return base;
    }
    final trimmed = detail.length <= 200
        ? detail
        : '${detail.substring(0, 200)}...';
    return '$base (cause: $trimmed)';
  }

  /// [cause]'s own text, or null when there is none.
  ///
  /// Never throws. The upload pipeline calls toString inside its catch to
  /// hand the text to markFailed, and if that call threw the row would stay
  /// 'transferring', which the drainer never selects, wedging the queue
  /// head (#1270). [cause] is an arbitrary Object?, so its toString is
  /// allowed to throw; [Error.safeToString] is the fallback, the same one
  /// CloudStorageException uses for its own cause.
  static String? _describe(Object? cause) {
    if (cause == null) return null;
    try {
      return cause.toString();
    } catch (_) {
      return Error.safeToString(cause);
    }
  }

  /// Whether [message] already says what [detail] says.
  ///
  /// A wrapped exception's `toString` is `ClassName: message`, but the
  /// mappers build their own message out of the wrapped message alone, so a
  /// plain containment check never matches on the path that wraps a whole
  /// CloudStorageException and the provider's explanation prints twice.
  static bool _messageCarries(String message, String detail) {
    if (message.contains(detail)) return true;
    final unprefixed = detail.replaceFirst(
      RegExp(r'^\w+(Exception|Error): '),
      '',
    );
    return unprefixed != detail && message.contains(unprefixed);
  }
}

/// Progress callback: [transferredBytes] so far; [totalBytes] null when
/// the total is unknown.
typedef TransferProgressCallback =
    void Function(int transferredBytes, int? totalBytes);

/// Object storage for media bytes (design spec section 8.1).
///
/// Deliberately file-based, never whole-Uint8List in its contract, so the
/// interface survives multipart/streaming internals without change and
/// callers keep memory bounded for arbitrarily large media. Keys are
/// store-relative (see StoreKeys); adapters apply any user-configured
/// remote prefix.
abstract class MediaObjectStore {
  /// Object metadata, or null when [key] does not exist.
  Future<StoreObjectInfo?> head(String key);

  /// Uploads [source] to [key], overwriting any existing object.
  ///
  /// [resumeStateJson] is adapter-opaque JSON from a previous interrupted
  /// attempt; callers persist whatever [onResumeStateChanged] hands them
  /// and replay it verbatim on retry.
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  });

  /// Downloads [key] into [destination]. Throws a [MediaStoreException]
  /// with [MediaStoreErrorKind.notFound] when the object is absent.
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  });

  /// Idempotent delete: absent keys succeed.
  Future<void> delete(String key);

  /// Best-effort abandonment of any provider-side resumable upload session
  /// recorded in [resumeStateJson] for [key] (orphan-prevention spec 5.5).
  /// Called when an upload is terminally failed and its resume state will
  /// never be replayed. Providers whose sessions self-expire (Dropbox,
  /// Drive, iCloud) no-op; must never throw on malformed or null state.
  Future<void> abandonResume(String key, String? resumeStateJson);

  /// All objects whose key starts with [keyPrefix].
  Stream<StoreObjectInfo> list(String keyPrefix);

  /// Aborts provider-side resumable upload sessions started before
  /// [olderThan]; returns how many were aborted. Grace-windowed so a
  /// session another device is actively resuming is never reaped
  /// (orphan-prevention spec 6.1). Providers whose sessions self-expire
  /// return 0.
  Future<int> reapStaleUploadSessions({required DateTime olderThan});
}
