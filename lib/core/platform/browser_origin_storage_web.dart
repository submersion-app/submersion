import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browser variant over `navigator.storage.getDirectory()` and
/// `window.location`.
abstract final class BrowserOriginStorage {
  /// Removes the top-level entry [name] of the origin private file system,
  /// files and directories alike; a missing entry is not an error.
  static Future<void> removeEntry(String name) async {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    try {
      await root
          .removeEntry(name, web.FileSystemRemoveOptions(recursive: true))
          .toDart;
    } catch (e) {
      // Gone already, or never created: nothing to remove.
      final stillThere = await _exists(root, name);
      if (stillThere) rethrow;
    }
  }

  static Future<bool> _exists(
    web.FileSystemDirectoryHandle root,
    String name,
  ) async {
    try {
      await root
          .getDirectoryHandle(
            name,
            web.FileSystemGetDirectoryOptions(create: false),
          )
          .toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  static void reloadPage() => web.window.location.reload();
}
