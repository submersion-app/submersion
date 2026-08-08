import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/repair/folder_candidate_source.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// One accepted proposal's DB write, prepared by Stage A.
class RepairWrite {
  const RepairWrite({
    required this.mediaId,
    this.newLocalPath,
    this.newBookmarkRef,
    this.newPlatformAssetId,
    this.newSourceType = MediaSourceType.localFile,
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
    this.log,
  });

  final MediaRepository repository;
  final MediaTransferQueueRepository queue;

  /// Platform bookmark hooks (macOS/iOS); null elsewhere.
  final Future<Uint8List> Function(String path)? createBookmark;
  final Future<void> Function(String ref, Uint8List blob)? writeBookmark;

  /// Audit trail (Media section Phase 5). Optional so the engine stays
  /// constructible in tests that do not care about history.
  final MediaRepairLogRepository? log;

  static const _log = LoggerService('MediaRepairService');
  static const _uuid = Uuid();

  Future<RepairApplyReport> apply(
    List<RepairProposal> accepted, {
    RepairLogSource source = RepairLogSource.manual,
  }) async {
    var failed = 0;
    var skipped = 0;
    var reuploadsQueued = 0;
    var cloudBacked = 0;

    final writes = <RepairWrite>[];
    final editedStamps = <({String mediaId, String hash, int sizeBytes})>[];
    final storeIds = <String>[];
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
          auditEntries.add(
            RepairLogEntry(
              id: _uuid.v4(),
              mediaId: proposal.item.id,
              batchId: batchId,
              occurredAt: now,
              action: RepairLogAction.cloudBacked,
              oldValue: oldPointer,
              source: source,
            ),
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
        final rowHash = proposal.item.contentHash;
        final matches = rowHash == null || hashed.hash == rowHash;

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
          newRef = proposal.item.bookmarkRef ?? _uuid.v4();
          await write(newRef, blob);
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
    await repository.applyRepairWrites(writes);

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
      await queue.enqueueUpload(mediaId: stamp.mediaId);
      reuploadsQueued++;
    }
    if (storeIds.isNotEmpty) {
      await repository.convertToCloudBacked(storeIds);
      cloudBacked = storeIds.length;
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
