import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Filter state for dive list
class DiveFilterState {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? diveTypeId;
  final String? siteId;
  final String? tripId;
  final String? diveCenterId;
  final double? minDepth;
  final double? maxDepth;
  final bool? favoritesOnly;
  final List<String> tagIds;

  // v1.5: Additional filter criteria
  final List<String> equipmentIds; // Upgraded from single equipmentId
  final String? buddyNameFilter; // Text search on buddy field
  final String?
  buddyId; // Filter by buddy ID (uses dive_buddies junction table)
  final List<String>
  diveIds; // Filter to specific dive IDs (e.g., shared dives with buddy)
  final double? minO2Percent; // Gas mix O2 filter (min)
  final double? maxO2Percent; // Gas mix O2 filter (max)
  final int? minRating; // Minimum star rating (1-5)
  final int? minDurationMinutes; // Minimum dive duration
  final int? maxDurationMinutes; // Maximum dive duration

  const DiveFilterState({
    this.startDate,
    this.endDate,
    this.diveTypeId,
    this.siteId,
    this.tripId,
    this.diveCenterId,
    this.minDepth,
    this.maxDepth,
    this.favoritesOnly,
    this.tagIds = const [],
    // v1.5 filters
    this.equipmentIds = const [],
    this.buddyNameFilter,
    this.buddyId,
    this.diveIds = const [],
    this.minO2Percent,
    this.maxO2Percent,
    this.minRating,
    this.minDurationMinutes,
    this.maxDurationMinutes,
  });

  bool get hasActiveFilters =>
      startDate != null ||
      endDate != null ||
      diveTypeId != null ||
      siteId != null ||
      tripId != null ||
      diveCenterId != null ||
      minDepth != null ||
      maxDepth != null ||
      favoritesOnly == true ||
      tagIds.isNotEmpty ||
      // v1.5 filters
      equipmentIds.isNotEmpty ||
      (buddyNameFilter != null && buddyNameFilter!.isNotEmpty) ||
      buddyId != null ||
      diveIds.isNotEmpty ||
      minO2Percent != null ||
      maxO2Percent != null ||
      minRating != null ||
      minDurationMinutes != null ||
      maxDurationMinutes != null;

  DiveFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? diveTypeId,
    String? siteId,
    String? tripId,
    String? diveCenterId,
    double? minDepth,
    double? maxDepth,
    bool? favoritesOnly,
    List<String>? tagIds,
    // v1.5 filters
    List<String>? equipmentIds,
    String? buddyNameFilter,
    String? buddyId,
    List<String>? diveIds,
    double? minO2Percent,
    double? maxO2Percent,
    int? minRating,
    int? minDurationMinutes,
    int? maxDurationMinutes,
    // Clear flags
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDiveType = false,
    bool clearSiteId = false,
    bool clearTripId = false,
    bool clearDiveCenterId = false,
    bool clearMinDepth = false,
    bool clearMaxDepth = false,
    bool clearFavoritesOnly = false,
    bool clearTagIds = false,
    bool clearEquipmentIds = false,
    bool clearBuddyNameFilter = false,
    bool clearBuddyId = false,
    bool clearDiveIds = false,
    bool clearMinO2Percent = false,
    bool clearMaxO2Percent = false,
    bool clearMinRating = false,
    bool clearMinDurationMinutes = false,
    bool clearMaxDurationMinutes = false,
  }) {
    return DiveFilterState(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      diveTypeId: clearDiveType ? null : (diveTypeId ?? this.diveTypeId),
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      tripId: clearTripId ? null : (tripId ?? this.tripId),
      diveCenterId: clearDiveCenterId
          ? null
          : (diveCenterId ?? this.diveCenterId),
      minDepth: clearMinDepth ? null : (minDepth ?? this.minDepth),
      maxDepth: clearMaxDepth ? null : (maxDepth ?? this.maxDepth),
      favoritesOnly: clearFavoritesOnly
          ? null
          : (favoritesOnly ?? this.favoritesOnly),
      tagIds: clearTagIds ? const [] : (tagIds ?? this.tagIds),
      // v1.5 filters
      equipmentIds: clearEquipmentIds
          ? const []
          : (equipmentIds ?? this.equipmentIds),
      buddyNameFilter: clearBuddyNameFilter
          ? null
          : (buddyNameFilter ?? this.buddyNameFilter),
      buddyId: clearBuddyId ? null : (buddyId ?? this.buddyId),
      diveIds: clearDiveIds ? const [] : (diveIds ?? this.diveIds),
      minO2Percent: clearMinO2Percent
          ? null
          : (minO2Percent ?? this.minO2Percent),
      maxO2Percent: clearMaxO2Percent
          ? null
          : (maxO2Percent ?? this.maxO2Percent),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      minDurationMinutes: clearMinDurationMinutes
          ? null
          : (minDurationMinutes ?? this.minDurationMinutes),
      maxDurationMinutes: clearMaxDurationMinutes
          ? null
          : (maxDurationMinutes ?? this.maxDurationMinutes),
    );
  }

  /// Filter a list of dives based on current filter state
  List<domain.Dive> apply(List<domain.Dive> dives) {
    return dives.where((dive) {
      // Date range filter
      if (startDate != null && dive.dateTime.isBefore(startDate!)) {
        return false;
      }
      if (endDate != null &&
          dive.dateTime.isAfter(endDate!.add(const Duration(days: 1)))) {
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

      // Trip filter
      if (tripId != null && dive.tripId != tripId) {
        return false;
      }

      // Dive center filter
      if (diveCenterId != null && dive.diveCenter?.id != diveCenterId) {
        return false;
      }

      // Equipment filter (match any selected equipment)
      if (equipmentIds.isNotEmpty) {
        final diveEquipmentIds = dive.equipment.map((e) => e.id).toSet();
        if (!equipmentIds.any((eqId) => diveEquipmentIds.contains(eqId))) {
          return false;
        }
      }

      // Depth filter
      if (minDepth != null &&
          (dive.maxDepth == null || dive.maxDepth! < minDepth!)) {
        return false;
      }
      if (maxDepth != null &&
          (dive.maxDepth == null || dive.maxDepth! > maxDepth!)) {
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

      // v1.5: Buddy name filter (text search on buddy field)
      if (buddyNameFilter != null && buddyNameFilter!.isNotEmpty) {
        final buddyLower = dive.buddy?.toLowerCase() ?? '';
        if (!buddyLower.contains(buddyNameFilter!.toLowerCase())) {
          return false;
        }
      }

      // v1.5: Dive IDs filter (for filtering to specific dives, e.g., shared with buddy)
      if (diveIds.isNotEmpty && !diveIds.contains(dive.id)) {
        return false;
      }

      // v1.5: Gas mix O2% filter (check any tank)
      if (minO2Percent != null || maxO2Percent != null) {
        if (dive.tanks.isEmpty) {
          return false;
        }
        // Check if any tank matches the O2% criteria
        final hasMatchingTank = dive.tanks.any((tank) {
          final o2 = tank.gasMix.o2;
          if (minO2Percent != null && o2 < minO2Percent!) return false;
          if (maxO2Percent != null && o2 > maxO2Percent!) return false;
          return true;
        });
        if (!hasMatchingTank) {
          return false;
        }
      }

      // v1.5: Rating filter
      if (minRating != null) {
        if (dive.rating == null || dive.rating! < minRating!) {
          return false;
        }
      }

      // v1.5: Duration filter
      if (minDurationMinutes != null || maxDurationMinutes != null) {
        final durationMinutes = dive.duration?.inMinutes;
        if (durationMinutes == null) {
          return false;
        }
        if (minDurationMinutes != null &&
            durationMinutes < minDurationMinutes!) {
          return false;
        }
        if (maxDurationMinutes != null &&
            durationMinutes > maxDurationMinutes!) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

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
    return sort.direction == SortDirection.ascending ? comparison : -comparison;
  });

  return sorted;
}

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
