import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../data/repositories/dive_repository_impl.dart';
import '../../domain/entities/dive.dart' as domain;

/// Filter state for dive list
class DiveFilterState {
  final DateTime? startDate;
  final DateTime? endDate;
  final DiveType? diveType;
  final String? siteId;
  final double? minDepth;
  final double? maxDepth;

  const DiveFilterState({
    this.startDate,
    this.endDate,
    this.diveType,
    this.siteId,
    this.minDepth,
    this.maxDepth,
  });

  bool get hasActiveFilters =>
      startDate != null ||
      endDate != null ||
      diveType != null ||
      siteId != null ||
      minDepth != null ||
      maxDepth != null;

  DiveFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    DiveType? diveType,
    String? siteId,
    double? minDepth,
    double? maxDepth,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDiveType = false,
    bool clearSiteId = false,
    bool clearMinDepth = false,
    bool clearMaxDepth = false,
  }) {
    return DiveFilterState(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      diveType: clearDiveType ? null : (diveType ?? this.diveType),
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      minDepth: clearMinDepth ? null : (minDepth ?? this.minDepth),
      maxDepth: clearMaxDepth ? null : (maxDepth ?? this.maxDepth),
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
      if (diveType != null && dive.diveType != diveType) {
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

/// All dives list provider
final divesProvider = FutureProvider<List<domain.Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getAllDives();
});

/// Single dive provider
final diveProvider = FutureProvider.family<domain.Dive?, String>((ref, id) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getDiveById(id);
});

/// Statistics provider
final diveStatisticsProvider = FutureProvider<DiveStatistics>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getStatistics();
});

/// Dive records (superlatives) provider
final diveRecordsProvider = FutureProvider<DiveRecords>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getRecords();
});

/// Next dive number provider
final nextDiveNumberProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getNextDiveNumber();
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

  DiveListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _loadDives();
  }

  Future<void> _loadDives() async {
    state = const AsyncValue.loading();
    try {
      final dives = await _repository.getAllDives();
      state = AsyncValue.data(dives);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadDives();
  }

  Future<domain.Dive> addDive(domain.Dive dive) async {
    final newDive = await _repository.createDive(dive);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
    return newDive;
  }

  Future<void> updateDive(domain.Dive dive) async {
    await _repository.updateDive(dive);
    await _loadDives();
    _ref.invalidate(diveStatisticsProvider);
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
}

final diveListNotifierProvider =
    StateNotifierProvider<DiveListNotifier, AsyncValue<List<domain.Dive>>>((ref) {
  final repository = ref.watch(diveRepositoryProvider);
  return DiveListNotifier(repository, ref);
});
