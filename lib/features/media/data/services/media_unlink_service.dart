import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

/// What an unlink actually did, so the caller can report it.
///
/// The three outcome types stay distinct because each unlink path leaves a
/// different link behind, but they share one field name: [keptLinked] counts
/// rows SOME OTHER attachment still needed, whatever that attachment is. The
/// field was named for the site case until equipment attachments landed
/// (issue #1517), at which point the name claimed more than it knew: a row
/// can now be kept because a piece of gear still files it.
class UnlinkOutcome {
  const UnlinkOutcome({required this.deleted, required this.keptLinked});

  /// Rows removed from the library entirely.
  final int deleted;

  /// Rows a dive site or a piece of equipment still needed, kept with only
  /// the dive link cleared.
  final int keptLinked;

  int get total => deleted + keptLinked;
}

/// What a site unlink did. Kept separate from [UnlinkOutcome] because the
/// carve-out runs the other way: here it is the DIVE (or the equipment) that
/// can still need the row.
class SiteUnlinkOutcome {
  const SiteUnlinkOutcome({required this.deleted, required this.keptLinked});

  final int deleted;

  /// Rows a dive or a piece of equipment still needed, kept with only the
  /// site link cleared.
  final int keptLinked;

  int get total => deleted + keptLinked;
}

/// What an equipment unlink did. A third outcome type rather than a reused
/// one for the same reason [SiteUnlinkOutcome] exists: the carve-out names
/// what still needs the row, and here that is a dive or a site.
class EquipmentUnlinkOutcome {
  const EquipmentUnlinkOutcome({
    required this.deleted,
    required this.keptLinked,
  });

  final int deleted;

  /// Rows a dive or a site still needed, kept with only the equipment link
  /// cleared.
  final int keptLinked;

  int get total => deleted + keptLinked;
}

/// The single implementation of "unlink media from a dive or a site",
/// shared by the Media section's selection bar and the dive and site detail
/// pages, so they can never drift apart on what unlinking means.
///
/// Unlinking removes the media from the library: the row, the cloud proxies
/// and the thumbnails, with a sync tombstone so the removal reaches the
/// user's other devices. It never touches the ORIGINAL source file. Nothing
/// on this path reads or writes `filePath`/`localPath`; the remote deletes
/// are keyed on `contentHash` and only ever address objects Submersion
/// uploaded. Re-linking the same file rebuilds the proxies and thumbnails
/// from it.
///
/// Media a dive site still references is the exception: it keeps the older
/// behaviour of merely clearing the dive link. That mirrors the
/// dive-deletion cascade's carve-out, and stops a dive-scoped action from
/// destroying a site's only photo as a side effect.
class MediaUnlinkService {
  MediaUnlinkService({
    required this.repository,
    required this.deleteMedia,
    this.deleteMediaUndrained,
    this.deleteMediaHeld,
    this.drainDeletes,
    GearPhotoRepository? gearPhotos,
  }) : _gearPhotos = gearPhotos;

  final MediaRepository repository;

  /// Clears a gear item's cover when its photo leaves (issue #3355).
  final GearPhotoRepository? _gearPhotos;

  /// The destructive half, injected rather than called directly: the real
  /// wiring is MediaDeletionCoordinator, which enqueues the remote blob
  /// delete intent BEFORE the row dies (the queue is a separate database,
  /// so no cross-DB transaction exists and this ordering makes the only
  /// crash window harmless).
  final Future<void> Function(List<String> ids) deleteMedia;

  /// [deleteMedia] without the media store's drain, for a delete filed as
  /// one History entry: the worker's other transfers must not be filed
  /// under it. [drainDeletes] runs once the entry has closed. Without
  /// these, [deleteMedia] is used and nothing more is drained. The drain is
  /// started, not awaited.
  final Future<void> Function(List<String> ids)? deleteMediaUndrained;

  /// [deleteMedia] for a delete inside a transaction that can still roll
  /// back: it leaves the worker for [drainDeletes] and purges only what this
  /// device remakes. A final delete's purge waits for a running species
  /// analysis of those photos, which writes outside the transaction, so it
  /// would wait on the transaction's lock forever.
  final Future<void> Function(List<String> ids)? deleteMediaHeld;
  final Future<void> Function()? drainDeletes;

  Future<UnlinkOutcome> unlinkFromDive(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return const UnlinkOutcome(deleted: 0, keptLinked: 0);
    }
    final split = await repository.partitionForDiveUnlink(mediaIds);

    // Kept first: it is the non-destructive half, so if the delete throws,
    // the site's media has already been correctly detached rather than left
    // pointing at a dive the user meant to leave.
    if (split.keptIds.isNotEmpty) {
      await repository.unlinkFromDive(split.keptIds);
    }
    if (split.deletable.isNotEmpty) {
      await deleteMedia(split.deletable);
    }

    return UnlinkOutcome(
      deleted: split.deletable.length,
      keptLinked: split.keptIds.length,
    );
  }

  /// Of [mediaIds], those that would actually lose something a user entered
  /// and no source file carries. Callers warn before unlinking when this is
  /// non-empty, and go straight through when it is not.
  ///
  /// Scoped to the rows this unlink would DELETE, not everything selected: a
  /// site-linked row survives, so its caption and favorite survive with it,
  /// and warning about them would be false.
  Future<Set<String>> idsWithUserMetadataAtRisk(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return {};
    final split = await repository.partitionForDiveUnlink(mediaIds);
    if (split.deletable.isEmpty) return {};
    return repository.idsWithUserMetadata(split.deletable);
  }

  /// The site-scoped twin of [unlinkFromDive]: rows a dive still references
  /// keep their row with the site link cleared, everything else leaves the
  /// library through the same destructive path.
  Future<SiteUnlinkOutcome> unlinkFromSite(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return const SiteUnlinkOutcome(deleted: 0, keptLinked: 0);
    }
    final split = await repository.partitionForSiteUnlink(mediaIds);
    if (split.keptIds.isNotEmpty) {
      await repository.unlinkFromSite(split.keptIds);
    }
    if (split.deletable.isNotEmpty) {
      await deleteMedia(split.deletable);
    }
    return SiteUnlinkOutcome(
      deleted: split.deletable.length,
      keptLinked: split.keptIds.length,
    );
  }

  /// The media library's Unlink: every link of every row goes, through the
  /// injected [deleteMedia], as one labelled entry in History (issue #4527).
  /// A gear item whose cover was one of them loses that cover, as the Gear
  /// tab's Remove clears it. Only the library's own bulk action comes here;
  /// the other callers of the deletion path keep their History as it is.
  Future<void> unlinkFromLibrary(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    await ChangeLogScope.bulk(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.unlinkMedia,
      body: () async {
        await (deleteMediaUndrained ?? deleteMedia)(mediaIds);
        await (_gearPhotos ?? GearPhotoRepository()).clearCoversNaming(
          mediaIds,
        );
      },
    );
    _drainAfterEntry();
  }

  /// The Media screen's Gear tab Remove: [unlinkFromEquipment] as one
  /// labelled entry in History (issue #4527), written in one transaction so
  /// a delete that fails leaves no photo half removed.
  Future<EquipmentUnlinkOutcome> removeGearPhotos(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return const EquipmentUnlinkOutcome(deleted: 0, keptLinked: 0);
    }
    final db = DatabaseService.instance.databaseOrNull;
    Future<EquipmentUnlinkOutcome> work() =>
        _unlinkFromEquipment(mediaIds, deleteMediaHeld ?? deleteMedia);
    final outcome = await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.removeGearPhotos,
      body: () => db == null ? work() : db.transaction(work),
    );
    _drainAfterEntry();
    return outcome;
  }

  /// Starts the media store's drain once the History entry has closed, and
  /// does not wait for it: the drain takes the whole transfer queue, uploads
  /// included, and the diver's action is done once the rows are.
  void _drainAfterEntry() {
    final drain = drainDeletes;
    if (drain == null) return;
    // Future.sync: a drain that throws before returning its future is logged
    // too, rather than failing an action whose rows are already gone.
    logFailure(Future.sync(drain), MediaUnlinkService, 'drain the media store');
  }

  /// The equipment twin of [unlinkFromSite]: rows a dive or site still
  /// references keep their row with the equipment link cleared, everything
  /// else leaves the library through the same destructive path.
  Future<EquipmentUnlinkOutcome> unlinkFromEquipment(List<String> mediaIds) =>
      _unlinkFromEquipment(mediaIds, deleteMedia);

  Future<EquipmentUnlinkOutcome> _unlinkFromEquipment(
    List<String> mediaIds,
    Future<void> Function(List<String> ids) delete,
  ) async {
    if (mediaIds.isEmpty) {
      return const EquipmentUnlinkOutcome(deleted: 0, keptLinked: 0);
    }
    final split = await repository.partitionForEquipmentUnlink(mediaIds);
    if (split.keptIds.isNotEmpty) {
      await repository.unlinkFromEquipment(split.keptIds);
    }
    if (split.deletable.isNotEmpty) {
      await delete(split.deletable);
    }
    await (_gearPhotos ?? GearPhotoRepository()).clearCoversNaming(mediaIds);
    return EquipmentUnlinkOutcome(
      deleted: split.deletable.length,
      keptLinked: split.keptIds.length,
    );
  }

  /// [idsWithUserMetadataAtRisk] for the site path: only rows the site
  /// unlink would delete can lose a caption or favorite.
  Future<Set<String>> idsWithUserMetadataAtRiskForSite(
    List<String> mediaIds,
  ) async {
    if (mediaIds.isEmpty) return {};
    final split = await repository.partitionForSiteUnlink(mediaIds);
    if (split.deletable.isEmpty) return {};
    return repository.idsWithUserMetadata(split.deletable);
  }
}
