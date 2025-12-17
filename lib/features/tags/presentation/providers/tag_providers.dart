import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/tag_repository.dart';
import '../../domain/entities/tag.dart';

/// Repository provider
final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository();
});

/// All tags list provider
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final repository = ref.watch(tagRepositoryProvider);
  return repository.getAllTags();
});

/// Single tag provider
final tagProvider = FutureProvider.family<Tag?, String>((ref, id) async {
  final repository = ref.watch(tagRepositoryProvider);
  return repository.getTagById(id);
});

/// Tag statistics provider
final tagStatisticsProvider = FutureProvider<List<TagStatistic>>((ref) async {
  final repository = ref.watch(tagRepositoryProvider);
  return repository.getTagStatistics();
});

/// Tags for a specific dive provider
final tagsForDiveProvider = FutureProvider.family<List<Tag>, String>((ref, diveId) async {
  final repository = ref.watch(tagRepositoryProvider);
  return repository.getTagsForDive(diveId);
});

/// Search tags provider
final tagSearchProvider = FutureProvider.family<List<Tag>, String>((ref, query) async {
  final repository = ref.watch(tagRepositoryProvider);
  return repository.searchTags(query);
});

/// Tag list notifier for mutations
class TagListNotifier extends StateNotifier<AsyncValue<List<Tag>>> {
  final TagRepository _repository;
  final Ref _ref;

  TagListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _loadTags();
  }

  Future<void> _loadTags() async {
    state = const AsyncValue.loading();
    try {
      final tags = await _repository.getAllTags();
      state = AsyncValue.data(tags);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadTags();
  }

  Future<Tag> addTag(Tag tag) async {
    final newTag = await _repository.createTag(tag);
    await _loadTags();
    _ref.invalidate(tagStatisticsProvider);
    return newTag;
  }

  Future<Tag> getOrCreateTag(String name, {String? colorHex}) async {
    final tag = await _repository.getOrCreateTag(name, colorHex: colorHex);
    await _loadTags();
    _ref.invalidate(tagStatisticsProvider);
    return tag;
  }

  Future<void> updateTag(Tag tag) async {
    await _repository.updateTag(tag);
    await _loadTags();
    _ref.invalidate(tagStatisticsProvider);
  }

  Future<void> deleteTag(String id) async {
    await _repository.deleteTag(id);
    await _loadTags();
    _ref.invalidate(tagStatisticsProvider);
  }

  Future<void> setTagsForDive(String diveId, List<Tag> tags) async {
    await _repository.setTagsForDive(diveId, tags);
    _ref.invalidate(tagStatisticsProvider);
  }

  Future<void> addTagToDive(String diveId, String tagId) async {
    await _repository.addTagToDive(diveId, tagId);
    _ref.invalidate(tagStatisticsProvider);
  }

  Future<void> removeTagFromDive(String diveId, String tagId) async {
    await _repository.removeTagFromDive(diveId, tagId);
    _ref.invalidate(tagStatisticsProvider);
  }
}

final tagListNotifierProvider =
    StateNotifierProvider<TagListNotifier, AsyncValue<List<Tag>>>((ref) {
  final repository = ref.watch(tagRepositoryProvider);
  return TagListNotifier(repository, ref);
});
