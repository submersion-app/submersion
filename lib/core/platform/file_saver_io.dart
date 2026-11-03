import 'dart:typed_data';

/// Native variant: exports leave through the share sheet or the save
/// dialog, never through here.
abstract final class FileSaver {
  static const bool isBrowserDownload = false;

  /// The browser variant's test hook; nothing reads it natively.
  static void Function(String url, String fileName)? debugDownload;

  static Future<void> saveBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async => throw UnsupportedError('downloads are a browser export');
}
