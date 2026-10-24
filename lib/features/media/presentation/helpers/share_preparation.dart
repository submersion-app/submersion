import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_share_temp_file.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/share_color_matrix.dart';
import 'package:submersion/features/media/presentation/helpers/video_share_timeline.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';

final _log = LoggerService.forClass(VideoShareProgress);

/// This platform's colour encoder for shared videos (issue #3521); null
/// where there is none (Linux).
final colorEncoderProvider = Provider<ColorEncoder?>(
  (ref) => colorEncoderForThisPlatform(),
);

/// Where a share is in re-encoding its corrected videos: the [index]th of
/// [total] (1-based), [fraction] of the way through, or null while its
/// correction is still being worked out.
class VideoShareProgress {
  const VideoShareProgress({
    required this.index,
    required this.total,
    this.fraction,
  });

  final int index;
  final int total;
  final double? fraction;
}

/// How preparing a share ended.
sealed class SharePreparation {
  const SharePreparation();
}

/// The files to share, and the videos whose correction could not be
/// applied (left out of [files], for the diver to share as originals).
final class ShareReady extends SharePreparation {
  const ShareReady({
    required this.files,
    required this.failedVideos,
    required this.correctedCopies,
  });

  final List<XFile> files;
  final List<MediaItem> failedVideos;

  /// The corrected copies written, to delete if the share is abandoned.
  final List<File> correctedCopies;
}

/// The diver cancelled; every corrected copy written was deleted.
final class ShareCancelled extends SharePreparation {
  const ShareCancelled();
}

/// The system stopped an encode (the app went into the background); every
/// corrected copy written was deleted.
final class ShareInterrupted extends SharePreparation {
  const ShareInterrupted();
}

/// Prepares [items] for the share sheet (issue #3521). Photos and videos
/// with nothing to correct are shared as today ([writeShareFileFor]); a
/// video with a correction is re-encoded into its share folder with the
/// colour timeline the viewer draws it with.
///
/// A video whose correction cannot be applied (no encoder, no file, an
/// encoder failure) is listed in [ShareReady.failedVideos] and the rest
/// carry on. [cancel] stops it ([ShareCancelled]); a failure or a stop the
/// diver did not ask for during an encode in which the app went into the
/// background (the [backgroundEntries] count moved) is [ShareInterrupted].
Future<SharePreparation> prepareShareFiles(
  WidgetRef ref,
  List<MediaItem> items, {
  required void Function(VideoShareProgress progress) onProgress,
  required ColorEncodeCancel cancel,
  int Function()? backgroundEntries,
}) async {
  final written = <File>[];
  try {
    return await _prepare(
      ref,
      items,
      onProgress: onProgress,
      cancel: cancel,
      backgroundEntries: backgroundEntries,
      written: written,
    );
  } catch (_) {
    // A resolve that throws part-way leaves no corrected copy behind.
    await deleteShareCopies(written);
    rethrow;
  }
}

Future<SharePreparation> _prepare(
  WidgetRef ref,
  List<MediaItem> items, {
  required void Function(VideoShareProgress progress) onProgress,
  required ColorEncodeCancel cancel,
  required int Function()? backgroundEntries,
  required List<File> written,
}) async {
  final total = items.where((i) => videoMayNeedCorrection(ref, i)).length;
  final files = <XFile>[];
  final failed = <MediaItem>[];
  var index = 0;

  Future<SharePreparation> abandon(SharePreparation outcome) async {
    await deleteShareCopies(written);
    return outcome;
  }

  for (final item in items) {
    if (cancel.isCancelled) return abandon(const ShareCancelled());
    if (!videoMayNeedCorrection(ref, item)) {
      final original = await _originalFile(ref, item);
      if (original != null) files.add(original);
      continue;
    }

    index++;
    onProgress(VideoShareProgress(index: index, total: total));
    final current = index;
    final path = await _filePathFor(ref, item);
    final bookmarkRef = item.bookmarkRef;
    if (path == null && (bookmarkRef == null || bookmarkRef.isEmpty)) {
      failed.add(item);
      continue;
    }
    final timeline = await videoShareTimelineFor(ref, item, path: path);
    if (timeline == null) {
      final original = await _originalFile(ref, item);
      if (original != null) files.add(original);
      continue;
    }
    final encoder = ref.read(colorEncoderProvider);
    if (encoder == null) {
      failed.add(item);
      continue;
    }

    final filename = p.setExtension(item.shareFilename, '.mp4');
    final output = await shareTempFileFor(item, filename: filename);
    final backgroundBefore = backgroundEntries?.call() ?? 0;
    try {
      final opened = await ref.read(videoFileAccessProvider)<bool>(
        path: path,
        bookmarkRef: bookmarkRef,
        read: (source) async {
          await encoder.encodeWithColor(
            source: File(source),
            output: output,
            timeline: timeline,
            cancel: cancel,
            onProgress: (f) => onProgress(
              VideoShareProgress(index: current, total: total, fraction: f),
            ),
          );
          return true;
        },
      );
      if (opened == null) {
        failed.add(item);
        continue;
      }
      written.add(output);
      files.add(XFile(output.path, mimeType: 'video/mp4', name: filename));
    } on TranscodeCancelledException {
      await deleteShareCopies([output]);
      return abandon(
        cancel.isCancelled ? const ShareCancelled() : const ShareInterrupted(),
      );
    } on Object catch (e, stackTrace) {
      await deleteShareCopies([output]);
      if ((backgroundEntries?.call() ?? 0) != backgroundBefore) {
        return abandon(const ShareInterrupted());
      }
      _log.warning(
        'Applying the colour correction to a shared video failed',
        error: e,
        stackTrace: stackTrace,
      );
      failed.add(item);
    }
  }
  if (cancel.isCancelled) return abandon(const ShareCancelled());
  return ShareReady(
    files: files,
    failedVideos: failed,
    correctedCopies: written,
  );
}

/// The share files for [items] as they are, without any video correction:
/// for videos whose correction could not be applied.
Future<List<XFile>> originalShareFiles(
  WidgetRef ref,
  List<MediaItem> items,
) async => [for (final item in items) ?await _originalFile(ref, item)];

/// Deletes corrected copies (and any encoder '.tmp' beside them).
Future<void> deleteShareCopies(List<File> copies) async {
  for (final file in copies) {
    for (final f in [file, File('${file.path}.tmp')]) {
      try {
        if (await f.exists()) await f.delete();
      } on FileSystemException catch (e) {
        _log.warning('Could not delete a share copy ${f.path}', error: e);
      }
    }
  }
}

Future<XFile?> _originalFile(WidgetRef ref, MediaItem item) async {
  final resolved = await ref.read(resolvedFullResolutionProvider(item).future);
  if (resolved.isUnavailable || resolved.bytes == null) return null;
  return writeShareFileFor(ref, item, resolved.bytes!);
}

Future<String?> _filePathFor(WidgetRef ref, MediaItem item) async {
  try {
    return await ref.read(resolvedFilePathProvider(item).future);
  } on Object catch (e, stackTrace) {
    _log.warning(
      'Resolving a shared video\'s file failed',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}
