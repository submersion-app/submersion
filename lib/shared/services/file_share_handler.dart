import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/shared/services/file_share_handler_io.dart'
    if (dart.library.html) 'package:submersion/shared/services/file_share_handler_web.dart'
    as platform;

/// Listens for files shared to the app via the OS share sheet (mobile only).
///
/// Call [initialize] once at app startup, and [dispose] when done.
/// On non-mobile platforms (and on web), [initialize] is a no-op.
class FileShareHandler {
  FileShareHandler({required this.onFileReceived, this.onError});

  /// Called when a file is shared to the app.
  /// Receives the file bytes and the original file name.
  final Future<void> Function(Uint8List bytes, String fileName) onFileReceived;

  /// Called when a shared file cannot be read or a platform error occurs.
  final void Function(Object error)? onError;

  final _delegate = platform.FileShareHandlerDelegate();

  /// Start listening for shared files. Only active on iOS and Android.
  void initialize() {
    _delegate.initialize(onFileReceived: onFileReceived, onError: onError);
  }

  @visibleForTesting
  Future<void> handleMediaFiles(List<dynamic> files) async {
    await _delegate.handleMediaFiles(
      files,
      onFileReceived: onFileReceived,
      onError: onError,
    );
  }

  void dispose() {
    _delegate.dispose();
  }
}
