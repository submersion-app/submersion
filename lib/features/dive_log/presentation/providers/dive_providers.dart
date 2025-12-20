import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dive_repository_impl.dart';
import '../../domain/entities/dive.dart' as domain;
import '../../../divers/presentation/providers/diver_providers.dart';

/// Filter state for dive list
class DiveFilterState {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? diveTypeId;
  final String? siteId;
  final double? minDepth;
  final double? maxDepth;
  final bool? favoritesOnly;
  final List<String> tagIds;

  const DiveFilterState({
    this.startDate,
    this.endDate,
    this.diveTypeId,
    this.siteId,
    this.minDepth,
    this.maxDepth,
    this.favoritesOnly,
    this.tagIds = const [],
  });

  bool get hasActiveFilters =>
      startDate != null ||
      endDate != null ||
      diveTypeId != null ||
      siteId != null ||
      minDepth != null ||
      maxDepth != null ||
      favoritesOnly == true ||
      tagIds.isNotEmpty;

  DiveFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? diveTypeId,
    String? siteId,
    double? minDepth,
    double? maxDepth,
    bool? favoritesOnly,
    List<String>? tagIds,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDiveType = false,
    bool clearSiteId = false,
    bool clearMinDepth = false,
    bool clearMaxDepth = false,
    bool clearFavoritesOnly = false,
    bool clearTagIds = false,
  }) {
    return DiveFilterState(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      diveTypeId: clearDiveType ? null : (diveTypeId ?? this.diveTypeId),
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      minDepth: clearMinDepth ? null : (minDepth ?? this.minDepth),
      maxDepth: clearMaxDepth ? null : (maxDepth ?? this.maxDepth),
      favoritesOnly: clearFavoritesOnly ? null : (favoritesOnly ?? this.favoritesOnly),
      tagIds: clearTagIds ? const [] : (tagIds ?? this.tagIds),
    );
  }

  /// Filter a list of dives based on current filter state
  List<domain.Dive> apply(List<domain.Dive> dives) {
    return dives.where((dive) {
      // Date range filter
      if (startDate != null && dive.dateTime.isBefore(startDate!)) {
        return false;
      }
      if (endDate != null && dive.dateTime.isAfter(endDate!.add(const Duration(days: 1)))) {
        return false;
      }

      // Dive type filter
      if (diveTypeId != null && dive.diveTypeId != diveTypeId) {
        return false;
      }

      // Site filter
      if (siteId != null && dive.site?.id != siteId) {
        return false;
      }

      // Depth filter
      if (minDepth != null && (dive.maxDepth == null || dive.maxDepth! < minDepth!)) {
        return false;
      }
      if (maxDepth != null && (dive.maxDepth == null || dive.maxDepth! > maxDepth!)) {
        return false;
      }

      // Favorites filter
      if (favoritesOnly == true && !dive.isFavorite) {
        return false;
      }

      // Tags filter (match any tag)
      if (tagIds.isNotEmpty) {
        final diveTagIds = dive.tags.map((t) => t.id).toSet();
        if (!tagIds.any((tagId) => diveTagIds.contains(tagId))) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

/// Dive filter state provider
final diveFilterProvider = StateProvider<DiveFilterState>((ref) => const DiveFilterState());

/// Filtered dives provider - applies current filter to dive list
final filteredDivesProvider = Provider<AsyncValue<List<domain.Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);

  return divesAsync.whenData((dives) => filter.apply(dives));
});

/// Repository provider
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});

/// All dives list provider (filtered by current diver)
final divesProvider = FutureProvider<List<domain.Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getAllDives(diverId: currentDiverId);
});

/// Single dive provider
final diveProvider = FutureProvider.family<domain.Dive?, String>((ref, id) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getDiveById(id);
});

/// Statistics provider (filtered by current diver)
final diveStatisticsProvider = FutureProvider<DiveStatistics>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getStatistics(diverId: currentDiverId);
});

/// Dive records (superlatives) provider (filtered by current diver)
final diveRecordsProvider = FutureProvider<DiveRecords>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getRecords(diverId: currentDiverId);
});

/// Next dive number provider (filtered by current diver)
final nextDiveNumberProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getNextDiveNumber(diverId: currentDiverId);
});

/// Search results provider
final diveSearchProvider = FutureProvider.family<List<domain.Dive>, String>((ref, query) async {
  if (query.isEmpty) {
    return ref.watch(divesProvider).value ?? [];
  }
  final repository = ref.watch(diveRepositoryProvider);
  return repository.searchDives(query);
});

/// Dive list notifier for mutations
class DiveListNotifier extends StateNotifier<AsyncValue<List<domain.Dive>>> {
  final DiveRepository _repository;
  final Ref _ref;
  String? _currentDiverId;

  DiveListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    // Watch for changes to current diver
    _currentDiverId = _ref.read(currentDiverIdProvider);
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        _currentDiverId = next;
        _loadDives();
      }
    });
    _loadDives();
  }

  Future<void> _loadDives() async {
    state = const AsyncValue.loading();
    try {
      final dives = await _repository.getAllDives(diverId: _currentDiverId);
      state = AsyncValue.data(dives);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadDives();
  }

  Future<domain.Dive> addDive(domain.Dive dive) async {
    // Ensure the dive is assigned to the current diver (if diver exists)
    var diveWithDiver = dive;
    if (dive.diverId == null && _currentDiverId != null) {
      // Verify the diver exists before assigning to avoid FK constraint errors
      final diverRepository = _ref.read(diverRepositoryProvider);
      final diverExists = await diverRepository.getDiverById(_currentDiverId!);
      if (diverExists != null) {
        diveWithDiver = dive.copyWith(diverId: _currentDiverId);
      }
    }
    final newDive = await _repository.createDive(diveWithDiver);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    return newDive;
  }

  Future<void> updateDive(domain.Dive dive) async {
    await _repository.updateDive(dive);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    _ref.invalidate(diveProvider(dive.id));
  }

  Future<void> deleteDive(String id) async {
    await _repository.deleteDive(id);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
  }

  /// Bulk delete multiple dives
  /// Returns the deleted dives for potential undo
  Future<List<domain.Dive>> bulkDeleteDives(List<String> ids) async {
    // Get the dives before deleting for undo capability
    final divesToDelete = await _repository.getDivesByIds(ids);
    await _repository.bulkDeleteDives(ids);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    return divesToDelete;
  }

  /// Restore multiple dives (for undo functionality)
  Future<void> restoreDives(List<domain.Dive> dives) async {
    for (final dive in dives) {
      await _repository.createDive(dive);
    }
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
  }

  /// Toggle favorite status for a dive
  Future<void> toggleFavorite(String diveId) async {
    await _repository.toggleFavorite(diveId);
    await _loadDives();
    _ref.invalidate(diveProvider(diveId));
  }

  /// Set favorite status for a dive
  Future<void> setFavorite(String diveId, bool isFavorite) async {
    await _repository.setFavorite(diveId, isFavorite);
    await _loadDives();
    _ref.invalidate(diveProvider(diveId));
  }
}

final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<domain.Dive>>>((ref) {
  final repository = ref.watch(diveRepositoryProvider);
  return DiveListNotifier(repository, ref);
});

/// Provider for getting the surface interval to the previous dive
final surfaceIntervalProvider = FutureProvider.family<Duration?, String>((ref, diveId) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getSurfaceInterval(diveId);
});

/// Provider for dive numbering information (gaps and unnumbered dives)
final diveNumberingInfoProvider = FutureProvider<DiveNumberingInfo>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getDiveNumberingInfo();
});
