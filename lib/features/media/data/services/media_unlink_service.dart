import 'package:submersion/features/media/data/repositories/media_repository.dart';

/// What an unlink actually did, so the caller can report it.
class UnlinkOutcome {
  const UnlinkOutcome({required this.deleted, required this.keptAsSiteMedia});

  /// Rows removed from the library entirely.
  final int deleted;

  /// Rows a dive site still needed, kept with the dive link cleared.
  final int keptAsSiteMedia;

  int get total => deleted + keptAsSiteMedia;
}

/// What a site unlink did. Kept separate from [UnlinkOutcome] because the
/// carve-out runs the other way: here it is the DIVE that can still need
/// the row.
class SiteUnlinkOutcome {
  const SiteUnlinkOutcome({
    required this.deleted,
    required this.keptAsDiveMedia,
  });

  final int deleted;
  final int keptAsDiveMedia;

  int get total => deleted + keptAsDiveMedia;
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
  MediaUnlinkService({required this.repository, required this.deleteMedia});

  final MediaRepository repository;

  /// The destructive half, injected rather than called directly: the real
  /// wiring is MediaDeletionCoordinator, which enqueues the remote blob
  /// delete intent BEFORE the row dies (the queue is a separate database,
  /// so no cross-DB transaction exists and this ordering makes the only
  /// crash window harmless).
  final Future<void> Function(List<String> ids) deleteMedia;

  Future<UnlinkOutcome> unlinkFromDive(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return const UnlinkOutcome(deleted: 0, keptAsSiteMedia: 0);
    }
    final split = await repository.partitionForDiveUnlink(mediaIds);

    // Kept first: it is the non-destructive half, so if the delete throws,
    // the site's media has already been correctly detached rather than left
    // pointing at a dive the user meant to leave.
    if (split.siteLinked.isNotEmpty) {
      await repository.unlinkFromDive(split.siteLinked);
    }
    if (split.deletable.isNotEmpty) {
      await deleteMedia(split.deletable);
    }

    return UnlinkOutcome(
      deleted: split.deletable.length,
      keptAsSiteMedia: split.siteLinked.length,
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
      return const SiteUnlinkOutcome(deleted: 0, keptAsDiveMedia: 0);
    }
    final split = await repository.partitionForSiteUnlink(mediaIds);
    if (split.diveLinked.isNotEmpty) {
      await repository.unlinkFromSite(split.diveLinked);
    }
    if (split.deletable.isNotEmpty) {
      await deleteMedia(split.deletable);
    }
    return SiteUnlinkOutcome(
      deleted: split.deletable.length,
      keptAsDiveMedia: split.diveLinked.length,
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
