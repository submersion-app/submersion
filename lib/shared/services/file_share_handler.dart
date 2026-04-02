import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Listens for files shared to the app via the OS share sheet (mobile only).
///
/// Call [initialize] once at app startup, and [dispose] when done.
/// On non-mobile platforms, [initialize] is a no-op.
class FileShareHandler {
  FileShareHandler({required this.onFileReceived, this.onError});

  /// Called when a file is shared to the app.
  /// Receives the file bytes and the original file name.
  final Future<void> Function(Uint8List bytes, String fileName) onFileReceived;

  /// Called when a shared file cannot be read.
  /// Receives the error for display or logging.
  final void Function(Object error)? onError;

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  /// Start listening for shared files. Only active on iOS and Android.
  void initialize() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Handle files shared while app is running
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      handleMediaFiles,
    );

    // Handle file that launched the app (cold start)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then(handleMediaFiles)
        .catchError((_) {});
  }

  @visibleForTesting
  Future<void> handleMediaFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final sharedFile = files.first;
    final file = File(sharedFile.path);
    if (!await file.exists()) return;

    try {
      final bytes = await file.readAsBytes();
      final fileName = file.uri.pathSegments.last;
      await onFileReceived(bytes, fileName);
    } catch (e) {
      onError?.call(e);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
