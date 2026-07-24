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
        // Repair-specific enqueue: re-arms a terminally failed row, which
        // plain enqueueUpload deliberately refuses to resurrect.
        await _queue.enqueueRepairUpload(mediaId: row.id);
        repairsQueued++;
      }
    }

    // Best-effort like the per-object deletes: by now the deletions and
    // repairs above have already happened, and a listing failure here must
    // not fail the sweep (or block the fleet lastSweepAt stamp) - missed
    // sessions simply wait for the next run.
    var sessionsAborted = 0;
    try {
      sessionsAborted = await _store.reapStaleUploadSessions(
        olderThan: now.subtract(staleSessionAge),
      );
    } on Exception catch (e) {
      _log.warning('Stale upload-session reap failed', error: e);
    }

    return VerifyLibraryReport(
      objectsChecked: objectsChecked,
      orphansRemoved: orphansRemoved,
      bytesReclaimed: bytesReclaimed,
      sessionsAborted: sessionsAborted,
      repairsQueued: repairsQueued,
    );
  }

  /// StoreKeys layout: a two-hex-char shard directory that must echo the
  /// hash's first two characters, a lowercase-hex hash, and a short
  /// alphanumeric extension. Anything else is treated as malformed and
  /// never deleted.
  static final _contentKeyShape = RegExp(
    r'^([0-9a-f]{2})/([0-9a-f]{4,64})\.[a-z0-9]{1,8}$',
  );

  /// `smv1/<tier>/<aa>/<hash>.<ext>` -> hash, or null when the key does
  /// not match the content-addressed shape (including a shard directory
  /// that does not match the hash, or a key outside [prefix]).
  String? _hashFromKey(String key, String prefix) {
    if (!key.startsWith(prefix)) return null;
    final match = _contentKeyShape.firstMatch(key.substring(prefix.length));
    if (match == null) return null;
    final hash = match.group(2)!;
    return hash.startsWith(match.group(1)!) ? hash : null;
  }
}
