import 'dart:typed_data';

/// Hashes one base transfer: the `sha256:<hex>` digest of each part, and a
/// rolling digest of the whole file.
///
/// Both are CPU work on megabytes of bytes, so a large transfer runs them on a
/// worker isolate instead of the isolate that called sync (issue #3829). Calls
/// are sequential: await each one before making the next.
abstract interface class BasePartHasher {
  /// Adds [part] to the whole-file hash and returns its digest. The caller
  /// keeps [part], unchanged, to upload or write.
  Future<String> addPart(Uint8List part);

  /// Completes the whole-file hash and returns its digest.
  Future<String> finish();

  /// Releases the worker, if any. Safe after a failure, and safe to repeat.
  Future<void> dispose();
}

/// A worker that started and then failed. The rolling hash died with it, so
/// the transfer cannot carry on inline: it fails, and the next sync retries.
class BasePartHasherException implements Exception {
  BasePartHasherException(this.message);

  final String message;

  @override
  String toString() => 'BasePartHasherException: $message';
}

typedef BasePartHasherOpener =
    Future<BasePartHasher> Function(int firstPartBytes);
