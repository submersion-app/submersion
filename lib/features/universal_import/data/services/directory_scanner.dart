import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// A user-granted folder to enumerate. On desktop [path] is an absolute
/// filesystem path; on Android it is a persisted `content://tree/...` URI
/// string; on iOS the durable grant is carried by [iosFolderBookmark]
/// instead (the [path] there is only the cosmetic picker path).
class GrantedFolder {
  /// Desktop: absolute path. Android: content:// tree URI string. iOS:
  /// unused for enumeration (see [iosFolderBookmark]).
  final String path;

  /// iOS only: the security-scoped FOLDER bookmark from the document picker.
  /// Resolved natively to walk the directory and mint per-file bookmarks.
  final Uint8List? iosFolderBookmark;

  const GrantedFolder({required this.path, this.iosFolderBookmark});
}

/// Platform abstraction enumerating a user-granted folder recursively and
/// yielding a persistable [ScannedFile] per file.
///
/// The iOS / macOS implementation MUST create each file's security-scoped
/// bookmark while the directory scope is held (during the walk), which is
/// why the stream yields a [ScannedFile] carrying a handle rather than
/// just a name. Callers enumerate exactly once per run.
abstract class DirectoryScanner {
  Stream<ScannedFile> scan(GrantedFolder folder);
}
