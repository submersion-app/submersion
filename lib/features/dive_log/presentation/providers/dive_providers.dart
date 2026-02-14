import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

// Re-export DiveFilterState so existing imports continue to work
export 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Dive filter state provider
final diveFilterProvider = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);

/// Dive sort state provider
final diveSortProvider = StateProvider<SortState<DiveSortField>>(
  (ref) => const SortState(
    field: DiveSortField.date,
    direction: SortDirection.descending,
  ),
);

/// Filtered dives provider - applies current filter to dive list
final filteredDivesProvider = Provider<AsyncValue<List<domain.Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);

  return divesAsync.whenData((dives) => filter.apply(dives));
});

/// Sorted and filtered dives provider - applies sort after filter
final sortedFilteredDivesProvider = Provider<AsyncValue<List<domain.Dive>>>((
  ref,
) {
  final divesAsync = ref.watch(filteredDivesProvider);
  final sort = ref.watch(diveSortProvider);

  return divesAsync.whenData((dives) => _applySorting(dives, sort));
});

/// Apply sorting to a list of dives
List<domain.Dive> _applySorting(
  List<domain.Dive> dives,
  SortState<DiveSortField> sort,
) {
  return PerfTimer.measureSync('applySorting', () {
    final sorted = List<domain.Dive>.from(dives);

    sorted.sort((a, b) {
      int comparison;
      // For text fields, invert direction (user expects descending = A→Z)
      final invertForText = sort.field == DiveSortField.site;

      switch (sort.field) {
        case DiveSortField.date:
          comparison = a.dateTime.compareTo(b.dateTime);
        case DiveSortField.site:
          comparison = (a.site?.name ?? '').compareTo(b.site?.name ?? '');
        case DiveSortField.depth:
          comparison = (a.maxDepth ?? 0).compareTo(b.maxDepth ?? 0);
        case DiveSortField.duration:
          final aDuration = a.duration?.inMinutes ?? 0;
          final bDuration = b.duration?.inMinutes ?? 0;
          comparison = aDuration.compareTo(bDuration);
        case DiveSortField.rating:
          comparison = (a.rating ?? 0).compareTo(b.rating ?? 0);
        case DiveSortField.diveNumber:
          comparison = (a.diveNumber ?? 0).compareTo(b.diveNumber ?? 0);
      }

      if (invertForText) {
        return sort.direction == SortDirection.ascending
            ? -comparison
            : comparison;
      }
      return sort.direction == SortDirection.ascending
          ? comparison
          : -comparison;
    });

    return sorted;
  });
}

/// Repository provider
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});

/// Custom field repository singleton
final diveCustomFieldRepositoryProvider = Provider<DiveCustomFieldRepository>((
  ref,
) {
  return DiveCustomFieldRepository(DatabaseService.instance.database);
});

/// Autocomplete suggestions: distinct keys this diver has used
final customFieldKeySuggestionsProvider =
    FutureProvider.family<List<String>, String>((ref, diverId) async {
      final repository = ref.watch(diveCustomFieldRepositoryProvider);
      return repository.getDistinctKeysForDiver(diverId);
    });

/// All dives list provider (filtered by current diver)
final divesProvider = FutureProvider<List<domain.Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getAllDives(diverId: currentDiverId);
});

/// Single dive provider
final diveProvider = FutureProvider.family<domain.Dive?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getDiveById(id);
});

/// Dive profile provider - for lazy loading profiles in list views
final diveProfileProvider =
    FutureProvider.family<List<domain.DiveProfilePoint>, String>((
      ref,
      diveId,
    ) async {
      final repository = ref.watch(diveRepositoryProvider);
      return repository.getDiveProfile(diveId);
    });

/// Batch profile cache for mini charts in the dive list.
///
/// Stores downsampled (~20 points) profiles keyed by dive ID. Populated in
/// bulk when a page of dives loads, avoiding N+1 per-tile queries.
final batchProfileCacheProvider =
    StateProvider<Map<String, List<domain.DiveProfilePoint>>>((ref) => {});

/// Version counter for statistics cache invalidation.
///
/// All statistics providers watch this. Bumping the version causes all of them
/// to re-fetch, while keepAlive prevents disposal between navigations.
final statisticsVersionProvider = StateProvider<int>((ref) => 0);

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
final diveSearchProvider = FutureProvider.family<List<domain.Dive>, String>((
  ref,
  query,
) async {
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  if (query.isEmpty) {
    return ref.watch(divesProvider).value ?? [];
  }
  final repository = ref.watch(diveRepositoryProvider);
  return repository.searchDives(query, diverId: validatedDiverId);
});

/// Dive list notifier for mutations
class DiveListNotifier extends StateNotifier<AsyncValue<List<domain.Dive>>> {
  final DiveRepository _repository;
  final Ref _ref;
  String? _currentDiverId;

  DiveListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
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

  /// Invalidate trip and dive center providers for a dive
  void _invalidateRelatedProviders(domain.Dive dive) {
    // Invalidate trip stats if dive has a trip (check both tripId and trip object)
    final tripId = dive.tripId ?? dive.trip?.id;
    if (tripId != null) {
      _ref.invalidate(tripWithStatsProvider(tripId));
    }
    // Invalidate dive center count if dive has a dive center
    if (dive.diveCenter != null) {
      _ref.invalidate(diveCenterDiveCountProvider(dive.diveCenter!.id));
    }
    // Refresh the trip list notifier (it's a StateNotifier so needs explicit refresh)
    _ref.read(tripListNotifierProvider.notifier).refresh();
    // Also invalidate the FutureProvider versions
    _ref.invalidate(allTripsWithStatsProvider);
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

    // If the dive was created without a dive number, renumber all dives
    // chronologically to ensure proper ordering
    if (dive.diveNumber == null) {
      await _repository.assignMissingDiveNumbers();
      _ref.invalidate(diveNumberingInfoProvider);
    }

    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    _invalidateRelatedProviders(newDive);
    return newDive;
  }

  Future<void> updateDive(domain.Dive dive) async {
    // Get old dive to invalidate old trip/center if changed
    final oldDive = await _repository.getDiveById(dive.id);
    await _repository.updateDive(dive);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    _ref.invalidate(diveProvider(dive.id));
    // Invalidate old associations
    if (oldDive != null) {
      _invalidateRelatedProviders(oldDive);
    }
    // Invalidate new associations
    _invalidateRelatedProviders(dive);
  }

  Future<void> deleteDive(String id) async {
    // Get dive before deleting to know its associations
    final dive = await _repository.getDiveById(id);
    await _repository.deleteDive(id);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    if (dive != null) {
      _invalidateRelatedProviders(dive);
    }
  }

  /// Bulk delete multiple dives
  /// Returns the deleted dives for potential undo
  Future<List<domain.Dive>> bulkDeleteDives(List<String> ids) async {
    // Get the dives before deleting for undo capability
    final divesToDelete = await _repository.getDivesByIds(ids);
    await _repository.bulkDeleteDives(ids);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    // Invalidate related providers for all deleted dives
    for (final dive in divesToDelete) {
      _invalidateRelatedProviders(dive);
    }
    return divesToDelete;
  }

  /// Restore multiple dives (for undo functionality)
  Future<void> restoreDives(List<domain.Dive> dives) async {
    for (final dive in dives) {
      await _repository.createDive(dive);
    }
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    // Invalidate related providers for all restored dives
    for (final dive in dives) {
      _invalidateRelatedProviders(dive);
    }
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

  // ============================================================================
  // Bulk Operations
  // ============================================================================

  /// Bulk update trip for multiple dives
  Future<void> bulkUpdateTrip(List<String> diveIds, String? tripId) async {
    await _repository.bulkUpdateTrip(diveIds, tripId);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    // Invalidate individual dive providers
    for (final diveId in diveIds) {
      _ref.invalidate(diveProvider(diveId));
    }
  }

  /// Bulk add tags to multiple dives
  Future<void> bulkAddTags(List<String> diveIds, List<String> tagIds) async {
    await _repository.bulkAddTags(diveIds, tagIds);
    await _loadDives();
    // Invalidate individual dive providers
    for (final diveId in diveIds) {
      _ref.invalidate(diveProvider(diveId));
    }
  }

  /// Bulk remove tags from multiple dives
  Future<void> bulkRemoveTags(List<String> diveIds, List<String> tagIds) async {
    await _repository.bulkRemoveTags(diveIds, tagIds);
    await _loadDives();
    // Invalidate individual dive providers
    for (final diveId in diveIds) {
      _ref.invalidate(diveProvider(diveId));
    }
  }
}

final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<domain.Dive>>>((
      ref,
    ) {
      final repository = ref.watch(diveRepositoryProvider);
      return DiveListNotifier(repository, ref);
    });

// ============================================================================
// Paginated Dive List (Performance-optimized for 5000+ dives)
// ============================================================================

/// Paginated dive list notifier using cursor-based pagination.
///
/// Loads [DiveSummary] objects in pages of 50, with SQL-level filtering.
/// Automatically reloads when the current diver or filter state changes.
class PaginatedDiveListNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>> {
  final DiveRepository _repository;
  final Ref _ref;
  String? _currentDiverId;
  static const _pageSize = 50;

  PaginatedDiveListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _currentDiverId = _ref.read(currentDiverIdProvider);
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        _currentDiverId = next;
        loadFirstPage();
      }
    });
    _ref.listen<DiveFilterState>(diveFilterProvider, (previous, next) {
      if (previous != next) {
        loadFirstPage();
      }
    });
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state = const AsyncValue.loading();
    try {
      final filter = _ref.read(diveFilterProvider);
      final results = await Future.wait([
        _repository.getDiveSummaries(
          diverId: _currentDiverId,
          filter: filter,
          limit: _pageSize,
        ),
        _repository.getDiveCount(diverId: _currentDiverId, filter: filter),
      ]);
      final dives = results[0] as List<DiveSummary>;
      final totalCount = results[1] as int;

      state = AsyncValue.data(
        PaginatedDiveListState(
          dives: dives,
          hasMore: dives.length >= _pageSize,
          nextCursor: _cursorFromLastDive(dives),
          totalCount: totalCount,
        ),
      );
      // Pre-load downsampled profiles for mini charts (fire and forget)
      _loadBatchProfiles(dives.map((d) => d.id).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final filter = _ref.read(diveFilterProvider);
      final newDives = await _repository.getDiveSummaries(
        diverId: _currentDiverId,
        filter: filter,
        cursor: current.nextCursor,
        limit: _pageSize,
      );

      state = AsyncValue.data(
        current.copyWith(
          dives: [...current.dives, ...newDives],
          isLoadingMore: false,
          hasMore: newDives.length >= _pageSize,
          nextCursor: _cursorFromLastDive(newDives),
        ),
      );
      // Pre-load downsampled profiles for the new page
      _loadBatchProfiles(newDives.map((d) => d.id).toList());
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Load downsampled profiles for a batch of dive IDs and merge into cache.
  Future<void> _loadBatchProfiles(List<String> diveIds) async {
    if (diveIds.isEmpty) return;
    // Skip IDs already in cache
    final cache = _ref.read(batchProfileCacheProvider);
    final uncached = diveIds.where((id) => !cache.containsKey(id)).toList();
    if (uncached.isEmpty) return;

    final profiles = await _repository.getBatchProfileSummaries(uncached);
    // Merge into cache (immutable update)
    _ref.read(batchProfileCacheProvider.notifier).state = {
      ...cache,
      ...profiles,
    };
  }

  Future<void> refresh() async {
    await loadFirstPage();
  }

  DiveSummaryCursor? _cursorFromLastDive(List<DiveSummary> dives) {
    if (dives.isEmpty) return null;
    final last = dives.last;
    return DiveSummaryCursor(
      sortTimestamp: last.sortTimestamp,
      diveNumber: last.diveNumber ?? 0,
      id: last.id,
    );
  }

  // --------------------------------------------------------------------------
  // Mutations — optimistic local state updates (no DB reload)
  // --------------------------------------------------------------------------

  void _invalidateRelatedProviders(domain.Dive dive) {
    final tripId = dive.tripId ?? dive.trip?.id;
    if (tripId != null) {
      _ref.invalidate(tripWithStatsProvider(tripId));
    }
    if (dive.diveCenter != null) {
      _ref.invalidate(diveCenterDiveCountProvider(dive.diveCenter!.id));
    }
    _ref.read(tripListNotifierProvider.notifier).refresh();
    _ref.invalidate(allTripsWithStatsProvider);
  }

  /// Also invalidate the old diveListNotifierProvider so legacy consumers
  /// (export, map views) stay in sync.
  void _invalidateOldProvider() {
    _ref.invalidate(diveListNotifierProvider);
  }

  /// Bump the statistics version to invalidate all cached stats providers,
  /// and also invalidate the dive-level stats provider.
  void _invalidateStatistics() {
    _ref.invalidate(diveStatisticsProvider);
    _ref.read(statisticsVersionProvider.notifier).state++;
  }

  Future<domain.Dive> addDive(domain.Dive dive) async {
    var diveWithDiver = dive;
    if (dive.diverId == null && _currentDiverId != null) {
      final diverRepository = _ref.read(diverRepositoryProvider);
      final diverExists = await diverRepository.getDiverById(_currentDiverId!);
      if (diverExists != null) {
        diveWithDiver = dive.copyWith(diverId: _currentDiverId);
      }
    }
    final newDive = await _repository.createDive(diveWithDiver);

    if (dive.diveNumber == null) {
      await _repository.assignMissingDiveNumbers();
      _ref.invalidate(diveNumberingInfoProvider);
    }

    // Optimistic: prepend new summary and bump totalCount
    final current = state.valueOrNull;
    if (current != null) {
      final summary = DiveSummary.fromDive(newDive);
      state = AsyncValue.data(
        current.copyWith(
          dives: [summary, ...current.dives],
          totalCount: current.totalCount + 1,
        ),
      );
    } else {
      await loadFirstPage();
    }

    _invalidateStatistics();
    _invalidateRelatedProviders(newDive);
    _invalidateOldProvider();
    return newDive;
  }

  Future<void> updateDive(domain.Dive dive) async {
    final oldDive = await _repository.getDiveById(dive.id);
    await _repository.updateDive(dive);

    // Optimistic: replace the item in the list by ID
    final current = state.valueOrNull;
    if (current != null) {
      final summary = DiveSummary.fromDive(dive);
      final updated = current.dives.map((d) {
        return d.id == dive.id ? summary : d;
      }).toList();
      state = AsyncValue.data(current.copyWith(dives: updated));
    } else {
      await loadFirstPage();
    }

    _invalidateStatistics();
    _ref.invalidate(diveProvider(dive.id));
    if (oldDive != null) _invalidateRelatedProviders(oldDive);
    _invalidateRelatedProviders(dive);
    _invalidateOldProvider();
  }

  Future<void> deleteDive(String id) async {
    final dive = await _repository.getDiveById(id);
    await _repository.deleteDive(id);

    // Optimistic: remove item by ID and decrement totalCount
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          dives: current.dives.where((d) => d.id != id).toList(),
          totalCount: current.totalCount - 1,
        ),
      );
    } else {
      await loadFirstPage();
    }

    _invalidateStatistics();
    if (dive != null) _invalidateRelatedProviders(dive);
    _invalidateOldProvider();
  }

  Future<List<domain.Dive>> bulkDeleteDives(List<String> ids) async {
    final divesToDelete = await _repository.getDivesByIds(ids);
    await _repository.bulkDeleteDives(ids);

    // Optimistic: remove items by IDs
    final idSet = ids.toSet();
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          dives: current.dives.where((d) => !idSet.contains(d.id)).toList(),
          totalCount: current.totalCount - ids.length,
        ),
      );
    } else {
      await loadFirstPage();
    }

    _invalidateStatistics();
    for (final dive in divesToDelete) {
      _invalidateRelatedProviders(dive);
    }
    _invalidateOldProvider();
    return divesToDelete;
  }

  Future<void> restoreDives(List<domain.Dive> dives) async {
    for (final dive in dives) {
      await _repository.createDive(dive);
    }
    // Restore is complex (ordering), reload first page
    await loadFirstPage();
    _invalidateStatistics();
    for (final dive in dives) {
      _invalidateRelatedProviders(dive);
    }
    _invalidateOldProvider();
  }

  Future<void> toggleFavorite(String diveId) async {
    // Optimistic: flip isFavorite immediately
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.dives.map((d) {
        return d.id == diveId ? d.copyWith(isFavorite: !d.isFavorite) : d;
      }).toList();
      state = AsyncValue.data(current.copyWith(dives: updated));
    }

    await _repository.toggleFavorite(diveId);
    _ref.invalidate(diveProvider(diveId));
    _invalidateOldProvider();
  }

  Future<void> setFavorite(String diveId, bool isFavorite) async {
    // Optimistic: set isFavorite immediately
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.dives.map((d) {
        return d.id == diveId ? d.copyWith(isFavorite: isFavorite) : d;
      }).toList();
      state = AsyncValue.data(current.copyWith(dives: updated));
    }

    await _repository.setFavorite(diveId, isFavorite);
    _ref.invalidate(diveProvider(diveId));
    _invalidateOldProvider();
  }

  Future<void> bulkUpdateTrip(List<String> diveIds, String? tripId) async {
    await _repository.bulkUpdateTrip(diveIds, tripId);
    // Bulk operations affect fields not in DiveSummary, reload
    await loadFirstPage();
    _invalidateStatistics();
    for (final diveId in diveIds) {
      _ref.invalidate(diveProvider(diveId));
    }
    _invalidateOldProvider();
  }

  Future<void> bulkAddTags(List<String> diveIds, List<String> tagIds) async {
    await _repository.bulkAddTags(diveIds, tagIds);
    // Tags changed — reload to get updated tag lists
    await loadFirstPage();
    for (final diveId in diveIds) {
      _ref.invalidate(diveProvider(diveId));
    }
    _invalidateOldProvider();
  }

  Future<void> bulkRemoveTags(List<String> diveIds, List<String> tagIds) async {
    await _repository.bulkRemoveTags(diveIds, tagIds);
    // Tags changed — reload to get updated tag lists
    await loadFirstPage();
    for (final diveId in diveIds) {
      _ref.invalidate(diveProvider(diveId));
    }
    _invalidateOldProvider();
  }
}

final paginatedDiveListProvider =
    StateNotifierProvider<
      PaginatedDiveListNotifier,
      AsyncValue<PaginatedDiveListState>
    >((ref) {
      final repository = ref.watch(diveRepositoryProvider);
      return PaginatedDiveListNotifier(repository, ref);
    });

/// Provider for getting the surface interval to the previous dive
final surfaceIntervalProvider = FutureProvider.family<Duration?, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getSurfaceInterval(diveId);
});

/// Provider for dive numbering information (gaps and unnumbered dives)
final diveNumberingInfoProvider = FutureProvider<DiveNumberingInfo>((
  ref,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getDiveNumberingInfo(diverId: validatedDiverId);
});

/// Repository provider for tank pressure data
final tankPressureRepositoryProvider = Provider<TankPressureRepository>((ref) {
  return TankPressureRepository();
});

/// Provider for per-tank time-series pressure data
///
/// Returns a map where keys are tank IDs and values are lists of
/// pressure points sorted by timestamp. Used for multi-tank pressure
/// visualization in the dive profile chart.
final tankPressuresProvider =
    FutureProvider.family<Map<String, List<domain.TankPressurePoint>>, String>((
      ref,
      diveId,
    ) async {
      final repository = ref.watch(tankPressureRepositoryProvider);
      return repository.getTankPressuresForDive(diveId);
    });
