import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/shared/services/shared_file_unreadable_exception.dart';

const _log = LoggerService('FileShareHandler');

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
    final unreadable = <String>[];
    for (final shared in files) {
      if (shared is! SharedMediaFile) {
        onError?.call(TypeError());
        return;
      }
      // A text or link share with no file attached carries the text itself
      // in `path`. It was never a file, so it is neither imported nor
      // reported. A file whose URI the plugin could not resolve looks the
      // same, so the skip is logged, by type only: the text may be private.
      if (!p.isAbsolute(shared.path)) {
        _log.info(
          'Ignored a shared ${shared.type.value} entry that is not a file '
          '(mime type: ${shared.mimeType ?? 'unknown'})',
        );
        continue;
      }
      // A path inside the sending app's private storage fails the stat, so
      // it reads as missing here even though the file is there (#2689).
      if (await File(shared.path).exists()) {
        paths.add(shared.path);
      } else {
        unreadable.add(shared.path);
      }
    }
    // Reported before the import runs, so a failing import cannot swallow
    // it; the readable files still go through below.
    if (unreadable.isNotEmpty) {
      onError?.call(
        SharedFileUnreadableException(
          unreadablePaths: unreadable,
          sharedCount: paths.length + unreadable.length,
        ),
      );
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
