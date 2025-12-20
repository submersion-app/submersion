import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/tag_repository.dart';
import '../../domain/entities/tag.dart';

/// Repository provider
final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository();
});

/// All tags list provider
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final repository = ref.watch(tagRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllTags(diverId: validatedDiverId);
});

/// Single tag provider
final tagProvider = FutureProvider.family<Tag?, String>((ref, id) async {
  final repository = ref.watch(tagRepositoryProvider);
  return repository.getTagById(id);
});

/// Tag statistics provider
final tagStatisticsProvider = FutureProvider<List<TagStatistic>>((ref) async {
  final repository = ref.watch(tagRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getTagStatistics(diverId: validatedDiverId);
});

/// Tags for a specific dive provider
final tagsForDiveProvider = FutureProvider.family<List<Tag>, String>((ref, diveId) async {
  final repository = ref.watch(tagRepositoryProvider);
  return repository.getTagsForDive(diveId);
});

/// Search tags provider
final tagSearchProvider = FutureProvider.family<List<Tag>, String>((ref, query) async {
  final repository = ref.watch(tagRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.searchTags(query, diverId: validatedDiverId);
});

/// Tag list notifier for mutations
class TagListNotifier extends StateNotifier<AsyncValue<List<Tag>>> {
  final TagRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  TagListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadTags();
  }

  Future<void> _loadTags() async {
    state = const AsyncValue.loading();
    try {
      final tags = await _repository.getAllTags(diverId: _validatedDiverId);
      state = AsyncValue.data(tags);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadTags();
    _ref.invalidate(tagsProvider);
  }

  Future<Tag> addTag(Tag tag) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new tags
    final tagWithDiver = tag.diverId == null && validatedId != null
        ? tag.copyWith(diverId: validatedId)
        : tag;
    final newTag = await _repository.createTag(tagWithDiver);
    await _loadTags();
    _ref.invalidate(tagStatisticsProvider);
    return newTag;
  }

  Future<Tag> getOrCreateTag(String name, {String? colorHex}) async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    final tag = await _repository.getOrCreateTag(name, colorHex: colorHex, diverId: validatedId);
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
