import 'package:flutter/services.dart';

/// A picked SAF directory: the persisted tree URI and its human display name.
class SafFolder {
  const SafFolder({required this.uri, required this.displayName});

  final String uri;
  final String displayName;
}

/// Thin Dart facade over the Android `app.submersion/saf` channel.
///
/// Android-only. Callers MUST guard with `Platform.isAndroid`; on other
/// platforms the channel has no handler and calls throw [MissingPluginException].
class SubmersionSaf {
  const SubmersionSaf._();

  static const MethodChannel _channel = MethodChannel('app.submersion/saf');

  /// Launches the system folder picker, persists read/write permission on the
  /// chosen tree, and returns it. Null if the user cancelled.
  static Future<SafFolder?> pickFolder() async {
    final res = await _channel.invokeMapMethod<String, dynamic>('pickFolder');
    if (res == null) return null;
    return SafFolder(
      uri: res['uri'] as String,
      displayName: res['displayName'] as String,
    );
  }

  /// Streams the file at [sourcePath] into [treeUri] as [fileName]. Returns the
  /// created document's URI (stored as the backup record's ref).
  static Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) async {
    final uri = await _channel.invokeMethod<String>('writeBackup', {
      'treeUri': treeUri,
      'fileName': fileName,
      'sourcePath': sourcePath,
    });
    return uri!;
  }

  /// Streams the document at [documentUri] out to [destPath] (a temp file used
  /// for restore/validation).
  static Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) => _channel.invokeMethod<void>('readBackup', {
    'documentUri': documentUri,
    'destPath': destPath,
  });

  /// Deletes the document at [documentUri]. Returns whether it was deleted.
  static Future<bool> delete(String documentUri) async =>
      await _channel.invokeMethod<bool>('delete', {
        'documentUri': documentUri,
      }) ??
      false;

  /// Whether the document at [documentUri] still exists.
  static Future<bool> exists(String documentUri) async =>
      await _channel.invokeMethod<bool>('exists', {
        'documentUri': documentUri,
      }) ??
      false;

  /// Returns the writable tree's display name, or null if the persisted grant
  /// is gone (revoked / folder deleted) -- the signal to self-heal.
  static Future<String?> resolveTree(String treeUri) =>
      _channel.invokeMethod<String?>('resolveTree', {'treeUri': treeUri});
}
