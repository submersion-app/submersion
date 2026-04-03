import 'dart:typed_data';

/// No-op web stub -- file sharing intents are not available on web.
class FileShareHandlerDelegate {
  void initialize({
    required Future<void> Function(Uint8List bytes, String fileName)
    onFileReceived,
    void Function(Object error)? onError,
  }) {}

  Future<void> handleMediaFiles(
    List<dynamic> files, {
    required Future<void> Function(Uint8List bytes, String fileName)
    onFileReceived,
    void Function(Object error)? onError,
  }) async {}

  void dispose() {}
}
