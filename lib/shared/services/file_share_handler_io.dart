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
    Future<void> Function(List<String> paths)? onFilesReceived,
    void Function(Object error)? onError,
  }) {
    if (!_isMobile) return;

    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => handleMediaFiles(
        files,
        onFileReceived: onFileReceived,
        onFilesReceived: onFilesReceived,
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
            onFilesReceived: onFilesReceived,
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
    Future<void> Function(List<String> paths)? onFilesReceived,
    void Function(Object error)? onError,
  }) async {
    if (files.isEmpty) return;

    final paths = <String>[];
    for (final shared in files) {
      if (shared is! SharedMediaFile) {
        onError?.call(TypeError());
        return;
      }
      if (await File(shared.path).exists()) paths.add(shared.path);
    }
    if (paths.isEmpty) return;

    try {
      // Several files go over as one batch, so exporting a handful of dives
      // at once imports them all rather than only the first (#1635).
      if (paths.length > 1 && onFilesReceived != null) {
        await onFilesReceived(paths);
        return;
      }

      final file = File(paths.first);
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
