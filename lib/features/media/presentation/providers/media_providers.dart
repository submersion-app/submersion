import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

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
  return repository.getMediaForDive(diveId);
});

/// Get single media by ID
final mediaByIdProvider = FutureProvider.family<MediaItem?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaById(id);
});

/// Get count for dive (for badges)
final mediaCountForDiveProvider = FutureProvider.family<int, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaCountForDive(diveId);
});

/// Get pending suggestion count for dive
final pendingSuggestionCountProvider = FutureProvider.family<int, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getPendingSuggestionCount(diveId);
});

/// Get all orphaned media
final orphanedMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getOrphanedMedia();
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

  /// Delete a media item
  Future<void> deleteMedia(String id) async {
    await _repository.deleteMedia(id);
    await refresh();
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
