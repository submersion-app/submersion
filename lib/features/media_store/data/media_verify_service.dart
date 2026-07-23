import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Outcome of one Verify Library run (orphan-prevention spec 6.3).
class VerifyLibraryReport {
  final int objectsChecked;
  final int orphansRemoved;
  final int bytesReclaimed;
  final int sessionsAborted;
  final int repairsQueued;

  const VerifyLibraryReport({
    required this.objectsChecked,
    required this.orphansRemoved,
    required this.bytesReclaimed,
    required this.sessionsAborted,
    required this.repairsQueued,
  });
}

/// True when an opportunistic verify sweep should run (orphan-prevention
/// spec 6.4): unmetered network and no fleet-wide sweep in the last 30
/// days. Pure so the gating is unit-testable apart from the runtime.
bool shouldAutoVerify({
  required DateTime? lastSweepAt,
  required NetworkKind network,
  required DateTime now,
}) {
  if (network != NetworkKind.unmetered) return false;
  if (lastSweepAt == null) return true;
  return now.difference(lastSweepAt) >= const Duration(days: 30);
}

/// Verify Library sweep (orphan-prevention spec section 6): reconciles the
/// store's namespaces against the media table.
///
/// Deletion needs BOTH unreferenced-ness and age (the 7-day grace window
/// protects rows still in flight from unsynced devices); repair needs only
/// absence (additive and idempotent). Every step is idempotent, so an
/// interrupted run simply resumes on the next one.
class MediaVerifyService {
  MediaVerifyService({
    required MediaObjectStore store,
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
    DateTime Function() now = DateTime.now,
  }) : _store = store,
       _mediaRepository = mediaRepository,
       _queue = queue,
       _now = now;

  static const graceWindow = Duration(days: 7);
  static const staleSessionAge = Duration(days: 7);

  static const _objectsPrefix = 'smv1/objects/';
  static const _thumbsPrefix = 'smv1/thumbs/';
  static const _renditionsPrefix = 'smv1/renditions/';

  final MediaObjectStore _store;
  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository _queue;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(MediaVerifyService);

  Future<VerifyLibraryReport> run({
    void Function(int objectsChecked)? onProgress,
  }) async {
    final now = _now();
    final graceCutoff = now.subtract(graceWindow);
    final referenced = await _mediaRepository.getAllContentHashes();

    var objectsChecked = 0;
    var orphansRemoved = 0;
    var bytesReclaimed = 0;

    // Hashes actually present per tier, for reverse repair below.
    final presentOriginals = <String>{};
    final presentThumbs = <String>{};
    final presentRenditions = <String>{};

    Future<void> sweepNamespace(String prefix, Set<String> present) async {
      await for (final info in _store.list(prefix)) {
        objectsChecked++;
        onProgress?.call(objectsChecked);
        final hash = _hashFromKey(info.key, prefix);
        if (hash == null) continue; // malformed keys are never deleted
        if (referenced.contains(hash)) {
          present.add(hash);
          continue;
        }
        if (!info.lastModified.isBefore(graceCutoff)) continue;
        try {
          await _store.delete(info.key);
          orphansRemoved++;
          bytesReclaimed += info.sizeBytes ?? 0;
        } on Exception catch (e) {
          // Best-effort per object; a miss stays for the next sweep.
          _log.warning('Verify sweep delete failed for ${info.key}', error: e);
        }
      }
    }

    await sweepNamespace(_objectsPrefix, presentOriginals);
    await sweepNamespace(_thumbsPrefix, presentThumbs);
    await sweepNamespace(_renditionsPrefix, presentRenditions);

    // Reverse repair (spec 6.2): a stamp whose object is absent is stale -
    // clear it and queue a re-upload; the pipeline re-materializes local
    // bytes when they resolve and fails gracefully when they do not.
    var repairsQueued = 0;
    for (final row in await _mediaRepository.getRemoteStampedSummaries()) {
      var repaired = false;
      if (row.hasOriginal && !presentOriginals.contains(row.contentHash)) {
        await _mediaRepository.clearRemoteUploaded(row.id);
        repaired = true;
      }
      if (row.hasThumb && !presentThumbs.contains(row.contentHash)) {
        await _mediaRepository.clearRemoteThumbUploaded(row.id);
        repaired = true;
      }
      if (row.hasRendition && !presentRenditions.contains(row.contentHash)) {
        await _mediaRepository.clearRemoteCompressed(row.id);
        repaired = true;
      }
      if (repaired) {
        await _queue.enqueueUpload(mediaId: row.id);
        repairsQueued++;
      }
    }

    final sessionsAborted = await _store.reapStaleUploadSessions(
      olderThan: now.subtract(staleSessionAge),
    );

    return VerifyLibraryReport(
      objectsChecked: objectsChecked,
      orphansRemoved: orphansRemoved,
      bytesReclaimed: bytesReclaimed,
      sessionsAborted: sessionsAborted,
      repairsQueued: repairsQueued,
    );
  }

  /// `smv1/<tier>/<aa>/<hash>.<ext>` -> hash, or null when the key does
  /// not match the content-addressed shape.
  String? _hashFromKey(String key, String prefix) {
    final rest = key.substring(prefix.length);
    final slash = rest.indexOf('/');
    if (slash < 0) return null;
    final file = rest.substring(slash + 1);
    final dot = file.lastIndexOf('.');
    if (dot <= 0) return null;
    final hash = file.substring(0, dot);
    return hash.isEmpty ? null : hash;
  }
}
