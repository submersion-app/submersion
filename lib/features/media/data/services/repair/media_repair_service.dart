import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';
import 'package:submersion/features/media/data/services/repair/folder_candidate_source.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Whether [candidate]'s file holds other bytes than [item]'s row records,
/// as the repair judges it: a row with no hash takes any bytes as its own,
/// and so does a file not hashed yet (the repair hashes it before judging).
bool relinkBringsOtherBytes(MediaItem item, RepairCandidate candidate) {
  final hash = candidate.hash;
  final rowHash = item.contentHash;
  return hash != null && rowHash != null && hash != rowHash;
}

/// [item] as a relink to [candidate]'s file writes it: Stage B's pointer
/// and verification columns, and for other bytes Stage C's new identity
/// with the store's upload stamps cleared, so the file is backed up again.
///
/// [originDeviceId] is the device the file resolves on (the one relinking
/// it) and [verifiedAt] the check the write records. The bookmark is the
/// one column it does not describe: the repair makes a new one where the
/// platform has bookmarks, which a drawing of the relink before it runs
/// cannot name, and leaves the row's own where it has none. It is drawn as
/// none (issue #4527).
MediaItem relinkedToFile(
  MediaItem item,
  RepairCandidate candidate, {
  required String? originDeviceId,
  required DateTime? verifiedAt,
}) {
  final otherBytes = relinkBringsOtherBytes(item, candidate);
  return item.copyWith(
    localPath: candidate.path,
    bookmarkRef: null,
    platformAssetId: null,
    sourceType: MediaSourceType.localFile,
    originDeviceId: originDeviceId,
    isOrphaned: false,
    lastVerifiedAt: verifiedAt,
    contentHash: otherBytes ? candidate.hash : item.contentHash,
    contentSizeBytes: otherBytes
        ? candidate.sizeBytes ?? 0
        : item.contentSizeBytes,
    remoteUploadedAt: otherBytes ? null : item.remoteUploadedAt,
    remoteThumbUploadedAt: otherBytes ? null : item.remoteThumbUploadedAt,
    remoteCompressedUploadedAt: otherBytes
        ? null
        : item.remoteCompressedUploadedAt,
  );
}

/// One accepted proposal's DB write, prepared by Stage A.
class RepairWrite {
  const RepairWrite({
    required this.mediaId,
    this.newLocalPath,
    this.newBookmarkRef,
    this.newPlatformAssetId,
    this.newSourceType = MediaSourceType.localFile,
    this.newCloudAssetId,
  });

  final String mediaId;
  final String? newLocalPath;
  final String? newBookmarkRef;
  final String? newPlatformAssetId;

  /// The source type the repaired row RESOLVES as, which the repair always
  /// restates rather than inherits: a candidate file on disk means
  /// [MediaSourceType.localFile] even when the row arrived as a gallery
  /// asset, and [MediaSourceType.platformGallery] pairs with
  /// [newPlatformAssetId].
  final MediaSourceType newSourceType;

  /// The new gallery asset's iCloud identifier, or null when it has none or
  /// the lookup failed. The repository writes null as '': the old id named
  /// the old asset, and an empty string (unlike null) reaches every peer.
  /// Unused for other sources.
  final String? newCloudAssetId;
}

/// Outcome counts of one apply pass, in wizard-summary terms.
class RepairApplyReport {
  const RepairApplyReport({
    required this.relinked,
    required this.cloudBacked,
    required this.reuploadsQueued,
    required this.failed,
    required this.skipped,
  });

  final int relinked;
  final int cloudBacked;
  final int reuploadsQueued;
  final int failed;
  final int skipped;
}

/// Staged repair apply (design spec section 6).
///
/// Stage A runs the fallible per-row I/O -- hash verification (promoting
/// probable to exact or demoting it to changed-on-disk) and bookmark
/// regeneration -- collecting failures without poisoning the batch.
/// Stage B commits every surviving write in one repository transaction.
/// Stage C performs the store side effects: edited rows re-stamp content
/// identity, clear their remote stamps, and enqueue a re-upload (the store
/// must never serve stale bytes); store proposals convert to cloud-backed.
class MediaRepairService {
  MediaRepairService({
    required this.repository,
    required this.queue,
    required this.createBookmark,
    required this.writeBookmark,
    this.deleteBookmark,
    this.log,
    this.cloudIdentifiers,
    this.assetCache,
    this.attachedStoreId,
  });

  final MediaRepository repository;
  final MediaTransferQueueRepository queue;

  /// Platform bookmark hooks (macOS/iOS); null elsewhere.
  final Future<Uint8List> Function(String path)? createBookmark;
  final Future<void> Function(String ref, Uint8List blob)? writeBookmark;

  /// Takes a bookmark away again: a held relink's new one, once its write
  /// has rolled back (see [apply]'s `onRollback`). Null keeps every one.
  final Future<void> Function(String ref)? deleteBookmark;

  /// Audit trail (Media section Phase 5). Optional so the engine stays
  /// constructible in tests that do not care about history.
  final MediaRepairLogRepository? log;

  /// Looks up a relinked gallery asset's iCloud identifier (spec 6.2);
  /// null leaves every gallery relink's cloud id empty.
  final CloudIdentifierSource? cloudIdentifiers;

  /// This device's resolution cache. It trusts a found mapping without
  /// re-proving it, so a relinked row's entry, which names the photo the
  /// row used to point at, is dropped after the relink commits. Peers drop
  /// theirs through the sync hook when the relink reaches them.
  final LocalAssetCacheRepository? assetCache;

  /// The media store this device is attached to, or null when detached.
  /// Store proposals convert only rows whose stamp was made in that store
  /// (issue #3482); with no store attached, or no lookup given, none do.
  final Future<String?> Function()? attachedStoreId;

  static const _log = LoggerService('MediaRepairService');
  static const _uuid = Uuid();

  /// [writes] with each gallery relink's new iCloud identifier, looked up
  /// in one batch (spec 6.2). A relink whose asset has none, or whose
  /// lookup failed, keeps null, which the repository writes as ''.
  Future<List<RepairWrite>> _withCloudIds(List<RepairWrite> writes) async {
    final galleryIds = [
      for (final w in writes)
        if (w.newSourceType == MediaSourceType.platformGallery &&
            w.newPlatformAssetId != null)
          w.newPlatformAssetId!,
    ];
    if (galleryIds.isEmpty) return writes;
    var cloudIds = const <String, String>{};
    final source = cloudIdentifiers;
    if (source != null) {
      try {
        cloudIds = await source.cloudIdentifiers(galleryIds);
      } on Object catch (e) {
        _log.warning('Could not read cloud ids for relinked assets: $e');
      }
    }
    return [
      for (final w in writes)
        w.newSourceType == MediaSourceType.platformGallery
            ? RepairWrite(
                mediaId: w.mediaId,
                newLocalPath: w.newLocalPath,
                newBookmarkRef: w.newBookmarkRef,
                newPlatformAssetId: w.newPlatformAssetId,
                newSourceType: w.newSourceType,
                newCloudAssetId: cloudIds[w.newPlatformAssetId],
              )
            : w,
    ];
  }

  /// With [afterCommit], the apply runs inside a write that can still be
  /// rolled back (a dive's sitting saved, issue #4527): what lives outside
  /// the database is left for the caller to run once that write commits,
  /// by adding it to [afterCommit] (the upload queue and the asset cache),
  /// and a file's bookmark goes under a new ref rather than over the
  /// row's, so a rolled-back row still resolves its old file. That new
  /// bookmark is written now; [onRollback] gets what takes it away again,
  /// for the caller to run if the write does not commit. It deletes only a
  /// bookmark no row refers to, so running it after a commit is harmless.
  Future<RepairApplyReport> apply(
    List<RepairProposal> accepted, {
    RepairLogSource source = RepairLogSource.manual,
    List<Future<void> Function()>? afterCommit,
    List<Future<void> Function()>? onRollback,
  }) => ChangeLogScope.bulk(
    DatabaseService.instance.databaseOrNull,
    label: ChangeLogLabels.mediaRepair,
    body: () => _applyInner(
      accepted,
      source: source,
      afterCommit: afterCommit,
      onRollback: onRollback,
    ),
  );

  Future<RepairApplyReport> _applyInner(
    List<RepairProposal> accepted, {
    RepairLogSource source = RepairLogSource.manual,
    List<Future<void> Function()>? afterCommit,
    List<Future<void> Function()>? onRollback,
  }) async {
    var failed = 0;
    var skipped = 0;
    var reuploadsQueued = 0;
    var cloudBacked = 0;

    final writes = <RepairWrite>[];
    final editedStamps = <({String mediaId, String hash, int sizeBytes})>[];
    final storeIds = <String>[];
    // Logged only for the rows the repository actually converts.
    final storeAudit = <String, RepairLogEntry>{};
    // One batch id per apply pass, so the history can group a wizard run.
    final batchId = _uuid.v4();
    final auditEntries = <RepairLogEntry>[];
    final now = DateTime.now();

    // Stage A: per-row I/O.
    for (final proposal in accepted) {
      final candidate = proposal.candidate;
      if (candidate == null) continue;

      final oldPointer = proposal.item.localPath ?? proposal.item.filePath;

      try {
        if (candidate.isStore) {
          storeIds.add(proposal.item.id);
          storeAudit[proposal.item.id] = RepairLogEntry(
            id: _uuid.v4(),
            mediaId: proposal.item.id,
            batchId: batchId,
            occurredAt: now,
            action: RepairLogAction.cloudBacked,
            oldValue: oldPointer,
            source: source,
          );
          continue;
        }

        if (candidate.isGallery) {
          writes.add(
            RepairWrite(
              mediaId: proposal.item.id,
              newPlatformAssetId: candidate.assetId,
              newSourceType: MediaSourceType.platformGallery,
            ),
          );
          auditEntries.add(
            RepairLogEntry(
              id: _uuid.v4(),
              mediaId: proposal.item.id,
              batchId: batchId,
              occurredAt: now,
              action: _actionFor(source),
              oldValue: oldPointer,
              newValue: candidate.assetId,
              source: source,
            ),
          );
          continue;
        }

        // File candidate: verify bytes against the row's content identity.
        final hashed = candidate.hash != null
            ? candidate
            : await FolderCandidateSource.withHash(candidate);
        final matches = !relinkBringsOtherBytes(proposal.item, hashed);

        if (!matches && proposal.confidence != RepairConfidence.edited) {
          // A probable match whose bytes changed on disk: never silently
          // relink different content -- report it for another review pass.
          skipped++;
          continue;
        }

        String? newRef;
        final create = createBookmark;
        final write = writeBookmark;
        if (create != null && write != null) {
          final blob = await create(candidate.path!);
          final ref = afterCommit == null
              ? proposal.item.bookmarkRef ?? _uuid.v4()
              : _uuid.v4();
          await write(ref, blob);
          newRef = ref;
          final delete = deleteBookmark;
          if (afterCommit != null && delete != null) {
            onRollback?.add(() async {
              if (await repository.countRowsWithBookmarkRef(ref) == 0) {
                await delete(ref);
              }
            });
          }
        }

        writes.add(
          RepairWrite(
            mediaId: proposal.item.id,
            newLocalPath: candidate.path,
            newBookmarkRef: newRef,
            // A file on disk resolves through LocalFileResolver whatever
            // the row used to be.
            newSourceType: MediaSourceType.localFile,
          ),
        );
        auditEntries.add(
          RepairLogEntry(
            id: _uuid.v4(),
            mediaId: proposal.item.id,
            batchId: batchId,
            occurredAt: now,
            action: _actionFor(source),
            oldValue: oldPointer,
            newValue: candidate.path,
            source: source,
          ),
        );
        if (!matches) {
          editedStamps.add((
            mediaId: proposal.item.id,
            hash: hashed.hash!,
            sizeBytes: hashed.sizeBytes ?? 0,
          ));
        }
      } on Exception catch (e) {
        _log.warning('Repair failed for ${proposal.item.id}: $e');
        failed++;
      }
    }

    // Stage B: one transaction for every surviving write.
    await repository.applyRepairWrites(await _withCloudIds(writes));
    Future<void> clearCache() async {
      try {
        await assetCache?.clearEntries([for (final w in writes) w.mediaId]);
      } on Object catch (e) {
        // The relink has committed; a stale entry costs one failed fetch,
        // after which the resolver re-resolves the row.
        _log.warning('Could not drop cached mappings for relinked rows: $e');
      }
    }

    if (afterCommit == null) {
      await clearCache();
    } else {
      afterCommit.add(clearCache);
    }

    // Stage C: store side effects.
    for (final stamp in editedStamps) {
      await repository.stampContentIdentity(
        stamp.mediaId,
        contentHash: stamp.hash,
        sizeBytes: stamp.sizeBytes,
      );
      await repository.clearRemoteUploaded(stamp.mediaId);
      await repository.clearRemoteThumbUploaded(stamp.mediaId);
      await repository.clearRemoteCompressed(stamp.mediaId);
      Future<void> enqueue() => queue.enqueueUpload(mediaId: stamp.mediaId);
      if (afterCommit == null) {
        await enqueue();
      } else {
        afterCommit.add(enqueue);
      }
      reuploadsQueued++;
    }
    if (storeIds.isNotEmpty) {
      final storeId = await attachedStoreId?.call();
      final converted = storeId == null
          ? const <String>{}
          : await repository.convertToCloudBacked(storeIds, storeId: storeId);
      cloudBacked = converted.length;
      // Refused rows (stamped only for another store, or no store attached)
      // keep their pointers and stay missing.
      skipped += storeIds.length - converted.length;
      auditEntries.addAll([
        for (final id in storeIds)
          if (converted.contains(id)) storeAudit[id]!,
      ]);
    }

    // Audit last: history records what actually happened, so it is written
    // only after the DB and store effects have gone through. That ordering
    // also means the repair is already committed here -- letting a history
    // failure escape would report a successful repair as failed and invite
    // a retry against rows that are no longer missing.
    try {
      await log?.record(auditEntries);
    } catch (e, stackTrace) {
      _log.warning(
        'Repair applied but the audit log write failed',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return RepairApplyReport(
      relinked: writes.length,
      cloudBacked: cloudBacked,
      reuploadsQueued: reuploadsQueued,
      failed: failed,
      skipped: skipped,
    );
  }

  /// The watcher applies without a human in the loop, which is worth
  /// distinguishing in the history from a repair the user confirmed.
  static RepairLogAction _actionFor(RepairLogSource source) =>
      source == RepairLogSource.watcher
      ? RepairLogAction.autoRelink
      : RepairLogAction.relink;
}
