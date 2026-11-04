import 'package:uuid/uuid.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';

/// The per-platform pointer a `localFile` media row stores for a file the
/// app references in place (the bytes are never copied).
///
/// Exactly what [LocalFileResolver] reads back: `localPath` first, then
/// `bookmarkRef` for platforms whose sandbox forgets a plain path once the
/// picker's grant lapses.
class LocalFileHandle {
  final String? localPath;
  final String? bookmarkRef;

  const LocalFileHandle({this.localPath, this.bookmarkRef});
}

/// Turns a filesystem path the user just granted into a [LocalFileHandle].
///
/// This is the one place that knows which platforms need a security-scoped
/// bookmark. The Files tab and the import wizard's photo attachment both
/// go through it, so a photo linked from an imported logbook is stored
/// exactly like one dragged into the Files tab and resolves the same way
/// after a restart.
class LocalFileHandleFactory {
  LocalFileHandleFactory({
    required LocalMediaPlatform platform,
    required LocalBookmarkStorage bookmarkStorage,
    bool? usesSecurityScopedBookmarks,
    bool? keepsPathBesideBookmark,
  }) : _platform = platform,
       _bookmarkStorage = bookmarkStorage,
       _usesBookmarks =
           usesSecurityScopedBookmarks ??
           (HostPlatform.isIOS || HostPlatform.isMacOS),
       _keepsPath = keepsPathBesideBookmark ?? HostPlatform.isMacOS;

  final LocalMediaPlatform _platform;
  final LocalBookmarkStorage _bookmarkStorage;

  /// iOS and macOS: the sandbox only re-admits a picked file through a
  /// security-scoped bookmark, so one is minted and stored in the keychain.
  final bool _usesBookmarks;

  /// macOS additionally keeps the absolute path: "Show in Finder" and the
  /// context menu's localPath gate need it. iOS does not, because the
  /// picker path is sandbox-scoped and useless after the session.
  final bool _keepsPath;

  static const _uuid = Uuid();

  Future<LocalFileHandle> create(String path) async {
    if (!_usesBookmarks) {
      // Android included: the path is either a file_picker cache copy or a
      // folder-scan result, never a SAF content URI, so there is nothing
      // persistable to take (issue #1002). The media store upload the
      // caller enqueues is what makes these rows durable.
      return LocalFileHandle(localPath: path);
    }
    final blob = await _platform.createBookmark(path);
    final bookmarkRef = _uuid.v4();
    await _bookmarkStorage.write(bookmarkRef, blob);
    return LocalFileHandle(
      localPath: _keepsPath ? path : null,
      bookmarkRef: bookmarkRef,
    );
  }
}
