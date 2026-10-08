import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';

const _log = LoggerService('RemotePhotoAttacher');

/// A photo a remote source listed for one of its dives, not yet downloaded.
class RemotePhoto {
  const RemotePhoto({required this.url, required this.fileName});

  /// Where the bytes are fetched from.
  final Uri url;

  /// The name the photo is saved under in the user's folder.
  final String fileName;
}

/// Photos attached, and photos that could not be downloaded or attached.
typedef RemotePhotoOutcome = ({int attached, int failed});

/// Downloads the photos of every dive that survived the import and hands
/// each to [attach] as a temp file.
///
/// Photos are keyed by the payload dive's `sourceUuid`, so the mapping holds
/// however the payload was re-indexed. [diveIdByIndex] maps payload dive
/// index to the dive the photo belongs on, which for a skipped or
/// consolidated duplicate is the existing dive it matched; a dive in
/// [removedDiveIds] was folded away and gets nothing. Each temp file sits in
/// its own folder, so two photos with the same name never collide, and the
/// whole temp tree is deleted before returning. A failure costs only that
/// photo: it is counted and the loop moves on, so photos can never fail an
/// import. An error [stopOn] accepts (a session that can no longer be
/// renewed) ends the run instead, counting every photo left as failed, so a
/// dead session is not retried once per photo.
Future<RemotePhotoOutcome> attachRemotePhotos({
  required Map<String, List<RemotePhoto>> photosBySourceUuid,
  required Map<int, String> diveIdByIndex,
  required Set<String> removedDiveIds,
  required List<Map<String, dynamic>> dives,
  required Map<String, DateTime> diveStartById,
  required Future<Uint8List> Function(Uri url) download,
  required Future<void> Function(File file, String diveId, DateTime? diveStart)
  attach,
  ImportCancellationToken? cancelToken,
  bool Function(Object error)? stopOn,
}) async {
  if (photosBySourceUuid.isEmpty || diveIdByIndex.isEmpty) {
    return (attached: 0, failed: 0);
  }
  final jobs = <({RemotePhoto photo, String diveId, DateTime? diveStart})>[
    for (final entry in diveIdByIndex.entries)
      if (!removedDiveIds.contains(entry.value) &&
          entry.key >= 0 &&
          entry.key < dives.length)
        for (final photo
            in photosBySourceUuid[dives[entry.key]['sourceUuid']] ??
                const <RemotePhoto>[])
          (
            photo: photo,
            diveId: entry.value,
            diveStart:
                diveStartById[entry.value] ??
                dives[entry.key]['dateTime'] as DateTime?,
          ),
  ];
  if (jobs.isEmpty) return (attached: 0, failed: 0);

  final tempRoot = await Directory.systemTemp.createTemp('remote_photos_');
  var attached = 0;
  var failed = 0;
  try {
    for (final (slot, job) in jobs.indexed) {
      if (cancelToken?.isCancelled ?? false) break;
      try {
        final bytes = await download(job.photo.url);
        final dir = Directory(p.join(tempRoot.path, '$slot'));
        await dir.create();
        final file = File(p.join(dir.path, job.photo.fileName));
        await file.writeAsBytes(bytes, flush: true);
        await attach(file, job.diveId, job.diveStart);
        attached++;
      } catch (e) {
        _log.warning('Could not attach remote photo ${job.photo.fileName}: $e');
        if (stopOn?.call(e) ?? false) {
          failed += jobs.length - slot;
          break;
        }
        failed++;
      }
    }
    return (attached: attached, failed: failed);
  } finally {
    try {
      await tempRoot.delete(recursive: true);
    } catch (e) {
      _log.warning('Could not delete remote photo temp folder: $e');
    }
  }
}
