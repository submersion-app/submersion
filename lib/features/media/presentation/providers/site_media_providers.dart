import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/document_import_service.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
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

/// Media from dives logged at the site, grouped by dive with empty dives
/// dropped. Same bounded fan-out as mediaForTripProvider: a single
/// Future.wait over every dive would fire hundreds of DB/IO calls at once
/// on a busy site, while sequential awaits grow first paint linearly.
final mediaFromDivesAtSiteProvider =
    FutureProvider.family<Map<Dive, List<MediaItem>>, String>((
      ref,
      siteId,
    ) async {
      final diveRepository = ref.watch(diveRepositoryProvider);
      // Which dives belong to the site is a dives-table read, so a merge, a
      // bulk delete, or a sync pull changes this grid without the media tables
      // being written. mediaCountForSiteProvider above already takes the media
      // tick; this needs the dives one as well (issue #974).
      ref.invalidateSelfWhen(diveRepository.watchDivesChanges());

      final dives = await diveRepository.getDivesForSite(siteId);
      if (dives.isEmpty) return {};

      const chunkSize = 12;
      final mediaLists = <List<MediaItem>>[];
      for (var offset = 0; offset < dives.length; offset += chunkSize) {
        final chunk = dives.skip(offset).take(chunkSize);
        mediaLists.addAll(
          await Future.wait(
            chunk.map(
              (dive) => ref.watch(mediaForDiveProvider(dive.id).future),
            ),
          ),
        );
      }

      final Map<Dive, List<MediaItem>> result = {};
      for (var i = 0; i < dives.length; i++) {
        if (mediaLists[i].isNotEmpty) {
          result[dives[i]] = mediaLists[i];
        }
      }
      return result;
    });

/// Flat, chronological dive-photo list for the site viewer.
final flatMediaFromDivesAtSiteProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, siteId) async {
      final grouped = await ref.watch(
        mediaFromDivesAtSiteProvider(siteId).future,
      );
      final all = grouped.values.expand((list) => list).toList();
      all.sort((a, b) => a.takenAt.compareTo(b.takenAt));
      return all;
    });

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
