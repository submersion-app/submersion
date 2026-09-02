import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_pinner.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Repository provider (singleton)
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository();
});

/// Get all media for a dive by diveId
final mediaForDiveProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  return repository.getMediaForDive(diveId);
});

/// Positions a dive's linked media on the profile chart by backfilling any
/// missing [MediaEnrichment] rows. Idempotent; wired to a dive-with-profile
/// loader and the media repository's read/save.
final diveMediaEnricherProvider = Provider<DiveMediaEnricher>((ref) {
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final diveRepo = ref.watch(diveRepositoryProvider);
  return DiveMediaEnricher(
    loadDive: diveRepo.getDiveById,
    loadMediaForDive: mediaRepo.getMediaForDive,
    saveEnrichments: mediaRepo.saveEnrichments,
  );
});

/// Applies the Set-time dialog's choice (issue #1090): one media-row write
/// plus one enrichment pass, so the new position lands on the next tick.
final mediaTimePinnerProvider = Provider<MediaTimePinner>((ref) {
  return MediaTimePinner(
    repository: ref.watch(mediaRepositoryProvider),
    enricher: ref.watch(diveMediaEnricherProvider),
  );
});

/// The one implementation of "unlink from a dive", shared by the Media
/// section's selection bar and dive detail's.
///
/// The coordinator is read lazily inside the closure rather than watched, so
/// consumer widget tests without a media-store runtime are unaffected. This
/// mirrors [mediaDeletionCoordinatorProvider]'s own reasoning.
final mediaUnlinkServiceProvider = Provider<MediaUnlinkService>((ref) {
  return MediaUnlinkService(
    repository: ref.watch(mediaRepositoryProvider),
    deleteMedia: (ids) =>
        ref.read(mediaDeletionCoordinatorProvider).deleteMultipleMedia(ids),
  );
});

/// Get single media by ID
final mediaByIdProvider = FutureProvider.family<MediaItem?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getMediaById(id);
});

/// Get count for dive (for badges)
final mediaCountForDiveProvider = FutureProvider.family<int, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getMediaCountForDive(diveId);
});

/// Get pending suggestion count for dive
final pendingSuggestionCountProvider = FutureProvider.family<int, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getPendingSuggestionCount(diveId);
});

/// Get all orphaned media
final orphanedMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repository = ref.watch(mediaRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchMediaChanges());
  return repository.getOrphanedMedia();
});

/// Get GPS coordinates from photos for a dive.
///
/// Returns the best GPS coordinates from the dive's photos, or null if
/// no photos have GPS data. Useful for suggesting dive site location.
final divePhotoGpsProvider =
    FutureProvider.family<({double latitude, double longitude})?, String>((
      ref,
      diveId,
    ) async {
      final repository = ref.watch(mediaRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchMediaChanges());
      return repository.getBestGpsFromDiveMedia(diveId);
    });

/// Get all GPS coordinates from photos for a dive (for showing multiple points).
final allDivePhotoGpsProvider =
    FutureProvider.family<
      List<({double latitude, double longitude, DateTime takenAt})>,
      String
    >((ref, diveId) async {
      final repository = ref.watch(mediaRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchMediaChanges());
      return repository.getGpsFromDiveMedia(diveId);
    });

/// MediaListNotifier for mutations on media for a specific dive
class MediaListNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  final MediaRepository _repository;
  final Ref _ref;
  final String _diveId;

  MediaListNotifier(this._repository, this._ref, this._diveId)
    : super(const AsyncValue.loading()) {
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    state = const AsyncValue.loading();
    try {
      final media = await _repository.getMediaForDive(_diveId);
      state = AsyncValue.data(media);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh the media list
  Future<void> refresh() async {
    await _loadMedia();
    _invalidateRelatedProviders();
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

  /// Delete a media item. Routed through the deletion coordinator so the
  /// remote-blob delete intent is enqueued before the row dies
  /// (orphan-prevention spec 5.2).
  Future<void> deleteMedia(String id) async {
    await _ref.read(mediaDeletionCoordinatorProvider).deleteMedia(id);
    await refresh();
  }

  /// Delete multiple media items at once
  Future<void> deleteMultipleMedia(List<String> ids) async {
    await _ref.read(mediaDeletionCoordinatorProvider).deleteMultipleMedia(ids);
    await refresh();
  }

  /// Unlinks from the dive: the rows leave the library, along with their
  /// cloud proxies and thumbnails, unless a dive site still needs them.
  /// Original source files are never touched. See [MediaUnlinkService].
  Future<UnlinkOutcome> unlinkMultipleMedia(List<String> ids) async {
    final outcome = await _ref
        .read(mediaUnlinkServiceProvider)
        .unlinkFromDive(ids);
    await refresh();
    return outcome;
  }

  /// Mark a media item as orphaned (photo deleted from gallery)
  Future<void> markAsOrphaned(String id) async {
    await _repository.markAsOrphaned(id);
    await refresh();
    _ref.invalidate(mediaByIdProvider(id));
    _ref.invalidate(orphanedMediaProvider);
  }

  void _invalidateRelatedProviders() {
    _ref.invalidate(mediaForDiveProvider(_diveId));
    _ref.invalidate(mediaCountForDiveProvider(_diveId));
    _ref.invalidate(divePhotoGpsProvider(_diveId));
    _ref.invalidate(allDivePhotoGpsProvider(_diveId));
    _ref.invalidate(orphanedMediaProvider);
  }
}

/// StateNotifierProvider for media list mutations (family by diveId)
final mediaListNotifierProvider =
    StateNotifierProvider.family<
      MediaListNotifier,
      AsyncValue<List<MediaItem>>,
      String
    >((ref, diveId) {
      final repository = ref.watch(mediaRepositoryProvider);
      return MediaListNotifier(repository, ref, diveId);
    });
