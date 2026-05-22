import 'dart:typed_data';

/// A platform-neutral, persistable reference to a single file produced by
/// a [DirectoryScanner] during enumeration. Exactly one of the three
/// reference forms is populated, matching the platform:
/// - desktop: [localPath]
/// - iOS / macOS: [bookmarkBlob] (a security-scoped bookmark created while
///   the directory scope was held)
/// - Android: [contentUri] (a per-file document URI under a persisted tree)
///
/// [LocalMediaLinker] consumes this without touching the filesystem again.
class MediaHandle {
  /// Desktop absolute filesystem path. Null on mobile.
  final String? localPath;

  /// iOS / macOS security-scoped bookmark blob, created during the scan
  /// while the directory's scope was held. Null off iOS / macOS.
  final Uint8List? bookmarkBlob;

  /// Android per-file content URI under a persisted tree. Null off Android.
  final String? contentUri;

  const MediaHandle({this.localPath, this.bookmarkBlob, this.contentUri})
    : assert(
        localPath != null || bookmarkBlob != null || contentUri != null,
        'MediaHandle requires at least one reference form',
      );

  /// Desktop convenience constructor.
  const MediaHandle.localPath(String path) : this(localPath: path);

  /// iOS / macOS convenience constructor.
  const MediaHandle.bookmark(Uint8List blob) : this(bookmarkBlob: blob);

  /// Android convenience constructor.
  const MediaHandle.contentUri(String uri) : this(contentUri: uri);

  /// The Android content URI to persist as `bookmarkRef` on the
  /// [MediaItem] row, or null when this is not an Android handle.
  String? get bookmarkRef => contentUri;
}

/// One file discovered during a [DirectoryScanner.scan]: its [basename]
/// (for filename-index resolution) plus a persistable [handle].
class ScannedFile {
  final String basename;
  final MediaHandle handle;

  const ScannedFile({required this.basename, required this.handle});
}
