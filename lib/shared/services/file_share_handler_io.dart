import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// dart:io implementation of the file share handler delegate.
class FileShareHandlerDelegate {
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void initialize({
    required Future<void> Function(Uint8List bytes, String fileName)
    onFileReceived,
    void Function(Object error)? onError,
  }) {
    if (!_isMobile) return;

    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => handleMediaFiles(
        files,
        onFileReceived: onFileReceived,
        onError: onError,
      ),
      onError: (Object e) => onError?.call(e),
    );

    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then(
          (files) => handleMediaFiles(
            files,
            onFileReceived: onFileReceived,
            onError: onError,
          ),
        )
        .catchError((Object error) {
          onError?.call(error);
        });
  }

  Future<void> handleMediaFiles(
    List<dynamic> files, {
    required Future<void> Function(Uint8List bytes, String fileName)
    onFileReceived,
    void Function(Object error)? onError,
  }) async {
    if (files.isEmpty) return;

    final sharedFile = files.first as SharedMediaFile;
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
