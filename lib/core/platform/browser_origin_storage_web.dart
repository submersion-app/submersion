import 'dart:js_interop';
import 'dart:math';

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

  /// The channel a tab tells the site's other tabs to reload on: it forgot
  /// the device, or its library changed underneath them (a restore, or a
  /// switch to or from the sample logbook). The name predates the second
  /// use and is kept, so a tab of the previous deployment still hears it.
  static const String reloadChannel = 'submersion-forget-device';

  /// This page's mark on what it announces. Two channel objects in one page
  /// hear each other, so without it the announcing tab would reload itself
  /// in the middle of the restore it is announcing.
  static final String _pageId =
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

  /// Tells every other tab of this site that the device was forgotten.
  static void announceForgotten() => _announce('forgotten');

  /// Tells every other tab of this site that the library they hold open is
  /// no longer the one in use (issue #4121).
  static void announceLibraryChanged() => _announce('library-changed');

  static void _announce(String what) {
    final channel = web.BroadcastChannel(reloadChannel);
    channel.postMessage('$what|$_pageId'.toJS);
    channel.close();
  }

  /// Calls [listener] when another tab asks the site's tabs to reload; the
  /// returned function stops listening. What this page announced itself is
  /// not heard.
  static void Function() onReloadAskedElsewhere(void Function() listener) {
    final channel = web.BroadcastChannel(reloadChannel);
    channel.onmessage = ((web.MessageEvent event) {
      final data = event.data;
      final message = data.isA<JSString>() ? (data as JSString).toDart : '';
      if (message.endsWith('|$_pageId')) return;
      listener();
    }).toJS;
    return () => channel.close();
  }
}
