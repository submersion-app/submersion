import 'package:collection/collection.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';

/// Removes what the marine life model left for media that is gone, and
/// clears it all on request (issue #4668).
///
/// Never throws: it runs after deletions that have already succeeded, and
/// anything left behind is picked up by [sweepOrphans].
class IdentificationCleanup {
  IdentificationCleanup({
    required MediaIdentificationRepository identifications,
    required IdentificationEmbeddingRepository embeddings,
    required IdentificationCropStore crops,
    Future<String?> Function()? deviceId,
  }) : _identifications = identifications,
       _embeddings = embeddings,
       _crops = crops,
       _deviceId = deviceId ?? (() async => null);

  final MediaIdentificationRepository _identifications;
  final IdentificationEmbeddingRepository _embeddings;
  final IdentificationCropStore _crops;

  /// This device's sync id, so the sweep knows the results it made itself.
  final Future<String?> Function() _deviceId;
  final _log = LoggerService.forClass(IdentificationCleanup);

  /// From the media deletion coordinator. A delete held for undo removes
  /// nothing: an undo puts the media rows back, and the diver's decisions on
  /// them must still be there.
  Future<void> onMediaDeleted(
    List<String> mediaIds, {
    required bool undoable,
  }) async {
    if (undoable || mediaIds.isEmpty) return;
    try {
      await _purge(mediaIds);
    } on Object catch (e) {
      _log.debug('Could not remove identifications of deleted media', error: e);
    }
  }

  /// Identifications whose media row is gone, with their crops and
  /// embeddings: deletions applied by sync, and deletes held for undo that
  /// were never undone. Then the crop files and embeddings of single
  /// identifications a peer deleted that sync's hook missed (issue #4890).
  /// Returns how many media items were cleared.
  ///
  /// Removed here only, never tombstoned (issue #4876): every device sweeps
  /// its own copies, and a tombstone from a sweep that saw a delete still
  /// held for undo would outrank the undo's republish on every device.
  Future<int> sweepOrphans() async {
    var cleared = 0;
    try {
      final orphans = await _identifications.orphanMediaIds(
        deviceId: await _deviceId(),
      );
      if (orphans.isNotEmpty) await _purge(orphans, publish: false);
      cleared = orphans.length;
    } on Object catch (e) {
      _log.debug('Could not sweep orphaned identifications', error: e);
    }
    try {
      await _sweepDeletedLeftovers();
    } on Object catch (e) {
      _log.debug('Could not sweep deleted identifications\' crops', error: e);
    }
    return cleared;
  }

  /// From sync, once an apply has ended: [deleted] are identifications a
  /// peer's tombstones deleted here (issue #4890), say a newer model run on
  /// another device replacing this one's. Their crop files and embeddings
  /// stay on this device unless removed here. Only ids whose row is gone
  /// are: the apply may have rolled back. No tombstone is asked for, since
  /// sync saw each row here, and its delete can commit with the log of its
  /// tombstone failed. Never throws; the launch sweep picks up what is
  /// left.
  Future<void> onDeletedBySync(
    List<({String mediaId, String id})> deleted,
  ) async {
    if (deleted.isEmpty) return;
    try {
      final gone = await _identifications.goneAmong([
        for (final d in deleted) d.id,
      ]);
      final byMedia = deleted
          .where((d) => gone.contains(d.id))
          .groupListsBy((d) => d.mediaId);
      await _removeLeftovers({
        for (final MapEntry(key: mediaId, value: rows) in byMedia.entries)
          mediaId: [for (final d in rows) d.id],
      });
    } on Object catch (e) {
      _log.debug(
        'Could not remove what deleted identifications left',
        error: e,
      );
    }
  }

  /// The crop files and embeddings of identifications this logbook has
  /// deleted (issue #4890): what a sync's hook missed, by a crash or a
  /// failure. The crops folder is shared by every logbook on the device, so
  /// only files of this logbook's photos whose id it holds a tombstone
  /// for, and only while the sync keeps that tombstone: at least 30 days,
  /// and until every peer has acknowledged it. A restored copy of this
  /// logbook shares its photos and ids, and is treated as this logbook, as
  /// every delete of a crop here is.
  /// Embeddings with no file behind them are left to the local cache
  /// sweep.
  Future<void> _sweepDeletedLeftovers() async {
    final onDisk = await _crops.fileIds();
    if (onDisk.isEmpty) return;
    // Only this logbook's photos: sync logs a peer's tombstone even for an
    // identification that was never here (issue #4890).
    final here = await _identifications.mediaHereAmong(onDisk.keys);
    final files = {
      for (final MapEntry(key: mediaId, value: ids) in onDisk.entries)
        if (here.contains(mediaId)) mediaId: ids,
    };
    if (files.isEmpty) return;
    final gone = await _identifications.deletedAmong(
      files.values.expand((ids) => ids),
    );
    if (gone.isEmpty) return;
    await _removeLeftovers({
      for (final MapEntry(key: mediaId, value: ids) in files.entries)
        if (ids.any(gone.contains))
          mediaId: [
            for (final id in ids)
              if (gone.contains(id)) id,
          ],
    });
  }

  /// Files first, then the embeddings, which no sync carries either.
  Future<void> _removeLeftovers(Map<String, List<String>> byMedia) async {
    if (byMedia.isEmpty) return;
    try {
      for (final MapEntry(key: mediaId, value: ids) in byMedia.entries) {
        await _crops.deleteFiles(mediaId, ids);
      }
    } finally {
      await _embeddings.delete([for (final ids in byMedia.values) ...ids]);
    }
  }

  /// Every identification in the open logbook, with its crops and
  /// embeddings. Only this logbook's: the crops folder and the embeddings
  /// are shared by every logbook opened on the device. Species tags are not
  /// touched.
  Future<void> clearAll() async {
    await _purge(await _identifications.mediaIds());
  }

  /// Rows first, then the synced crops, then what stays on this device:
  /// an embeddings store that cannot be reached (a browser has none) must
  /// not leave crops behind that would go on syncing (issue #4876).
  /// [publish] tombstones what it removes, so peers drop it too.
  Future<void> _purge(List<String> mediaIds, {bool publish = true}) async {
    final ids = await _identifications.deleteForMedia(
      mediaIds,
      publish: publish,
    );
    try {
      await _crops.deleteMedia(mediaIds, publish: publish);
    } finally {
      await _embeddings.delete(ids);
    }
  }
}
