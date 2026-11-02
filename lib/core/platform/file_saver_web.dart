import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:web/web.dart' as web;

/// Browser variant: the bytes become a Blob behind an object URL, which a
/// temporary anchor downloads under [fileName].
abstract final class FileSaver {
  static const bool isBrowserDownload = true;

  /// Takes the object URL and name instead of clicking the anchor, so a
  /// test can check the blob without a download.
  @visibleForTesting
  static void Function(String url, String fileName)? debugDownload;

  static Future<void> saveBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final hook = debugDownload;
    if (hook != null) {
      hook(url, fileName);
      return;
    }
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    // The browser reads the blob after the click returns; a minute is
    // ample before the URL is let go.
    Future<void>.delayed(const Duration(minutes: 1), () {
      web.URL.revokeObjectURL(url);
    });
  }
}
