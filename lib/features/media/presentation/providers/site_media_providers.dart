import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/data/repositories/site_dive_media_repository.dart';
import 'package:submersion/features/media/data/services/document_import_service.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Media directly attached to a site (attachments group), ordered by takenAt.
final mediaForSiteProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getMediaForSite(siteId);
});

/// Count of direct site attachments (badges/headers).
final mediaCountForSiteProvider = FutureProvider.family<int, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getMediaCountForSite(siteId);
});

final siteDiveMediaRepositoryProvider = Provider<SiteDiveMediaRepository>(
  (ref) => SiteDiveMediaRepository(),
);

/// How many media items the dives logged at the site hold: all Site Details
/// needs to decide whether to show the dive photos card and to title it, so
/// a site with hundreds of dives and no photos costs one count (issues #4252
/// and #4502).
///
/// Which dives belong to the site is a dives-table read, so a merge, a bulk
/// delete, or a sync pull changes this without the media table being written
/// (issue #974); it takes the dives tick as well as the media one.
final mediaCountFromDivesAtSiteProvider = FutureProvider.family<int, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(siteDiveMediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchCountChanges());
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  return repository.countMediaFromDivesAtSite(siteId);
});

/// Every media item from the dives logged at the site, chronological, for
/// the dive photos card's Show all grid and the site viewer. Read in one
/// statement and only while one of them is open; the card's strip reads
/// [recentMediaFromDivesAtSiteProvider] and the page
/// [mediaCountFromDivesAtSiteProvider] instead.
///
/// Takes the whole media tick, enrichment included, because the viewer shows
/// the enrichment, and the dives tick for the same reason as the count.
final flatMediaFromDivesAtSiteProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, siteId) async {
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      return ref
          .watch(siteDiveMediaRepositoryProvider)
          .getMediaFromDivesAtSite(siteId);
    });

/// Most photos the strip on the site's dive photos card reads: enough to fill
/// one row on a wide desktop card. The card shows as many as fit.
const int kSiteDivePhotoStripLimit = 12;

/// The newest [kSiteDivePhotoStripLimit] media items from the dives logged at
/// the site, for the strip on the site's dive photos card (issue #4502).
///
/// Takes the same ticks as [flatMediaFromDivesAtSiteProvider], for the same
/// reasons: the viewer it opens shows the enrichment, and which dives belong
/// to the site is a dives-table read.
final recentMediaFromDivesAtSiteProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, siteId) async {
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      return ref
          .watch(siteDiveMediaRepositoryProvider)
          .getRecentMediaFromDivesAtSite(
            siteId,
            limit: kSiteDivePhotoStripLimit,
          );
    });

/// Narrow writers for a site attachment's name, category and size
/// (issue #1039).
final siteAttachmentRepositoryProvider = Provider<SiteAttachmentRepository>(
  (ref) => SiteAttachmentRepository(),
);

/// Mutations on a site's direct attachments. Site counterpart of
/// MediaListNotifier.
class SiteMediaListNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  final MediaRepository _repository;
  final Ref _ref;
  final String _siteId;

  SiteMediaListNotifier(this._repository, this._ref, this._siteId)
    : super(const AsyncValue.loading()) {
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    state = const AsyncValue.loading();
    try {
      final media = await _repository.getMediaForSite(_siteId);
      state = AsyncValue.data(media);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh the media list
  Future<void> refresh() async {
    await _loadMedia();
    _ref.invalidate(mediaForSiteProvider(_siteId));
    _ref.invalidate(mediaCountForSiteProvider(_siteId));
  }

  /// Add a new media item
  Future<MediaItem> addMedia(MediaItem item) async {
    final newItem = await _repository.createMedia(item);
    await refresh();
    return newItem;
  }

  /// Update an existing media item
  Future<void> updateMedia(MediaItem item) async {
    await _repository.updateMedia(item);
    await refresh();
    _ref.invalidate(mediaByIdProvider(item.id));
  }

  /// Saves an Edit details sheet: only the fields [edit] carries.
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async {
    await _ref
        .read(siteAttachmentRepositoryProvider)
        .setAttachmentDetails(id, edit);
    await refresh();
    _ref.invalidate(mediaByIdProvider(id));
  }

  /// Puts every attachment in [ids] into [category]; null uncategorizes.
  /// Returns how many were updated (ids unlinked meanwhile are skipped).
  Future<int> setSiteCategory(
    List<String> ids,
    SiteAttachmentCategory? category,
  ) async {
    final updated = await _ref
        .read(siteAttachmentRepositoryProvider)
        .setSiteCategory(ids, category);
    await refresh();
    return updated;
  }

  /// Delete media items. Routed through the deletion coordinator so
  /// remote-blob delete intents are enqueued before rows die
  /// (orphan-prevention spec 5.2).
  Future<void> deleteMultipleMedia(List<String> ids) async {
    await _ref.read(mediaDeletionCoordinatorProvider).deleteMultipleMedia(ids);
    await refresh();
  }

  /// Unlinks from the site: rows leave the library unless a dive still
  /// needs them. Original source files are never touched. See
  /// [MediaUnlinkService].
  Future<SiteUnlinkOutcome> unlinkMultipleMedia(List<String> ids) async {
    final outcome = await _ref
        .read(mediaUnlinkServiceProvider)
        .unlinkFromSite(ids);
    await refresh();
    return outcome;
  }
}

/// Reference-linking document attach service (dive and site targets).
final documentImportServiceProvider = Provider<DocumentImportService>((ref) {
  return DocumentImportService(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    platform: ref.watch(localMediaPlatformProvider),
    bookmarkStorage: ref.watch(localBookmarkStorageProvider),
    onMediaCreated: ref.watch(mediaStoreEnqueueProvider),
  );
});

/// StateNotifierProvider for site attachment mutations (family by siteId)
final siteMediaListNotifierProvider =
    StateNotifierProvider.family<
      SiteMediaListNotifier,
      AsyncValue<List<MediaItem>>,
      String
    >((ref, siteId) {
      final repository = ref.watch(mediaRepositoryProvider);
      return SiteMediaListNotifier(repository, ref, siteId);
    });
