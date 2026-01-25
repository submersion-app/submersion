import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

/// Repository provider
final buddyRepositoryProvider = Provider<BuddyRepository>((ref) {
  return BuddyRepository();
});

/// All buddies provider
final allBuddiesProvider = FutureProvider<List<Buddy>>((ref) async {
  final repository = ref.watch(buddyRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllBuddies(diverId: validatedDiverId);
});

/// Buddy sort state provider
final buddySortProvider = StateProvider<SortState<BuddySortField>>(
  (ref) => const SortState(
    field: BuddySortField.name,
    direction: SortDirection.descending,
  ),
);

/// All buddies with dive counts provider (for efficient sorting by dive count)
final allBuddiesWithDiveCountProvider =
    FutureProvider<List<BuddyWithDiveCount>>((ref) async {
      final repository = ref.watch(buddyRepositoryProvider);
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      return repository.getAllBuddiesWithDiveCount(diverId: validatedDiverId);
    });

/// Apply sorting to a list of buddies with dive counts
List<BuddyWithDiveCount> applyBuddyWithDiveCountSorting(
  List<BuddyWithDiveCount> buddies,
  SortState<BuddySortField> sort,
) {
  final sorted = List<BuddyWithDiveCount>.from(buddies);

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A→Z)
    final invertForText = sort.field == BuddySortField.name;

    switch (sort.field) {
      case BuddySortField.name:
        comparison = a.buddy.name.toLowerCase().compareTo(
          b.buddy.name.toLowerCase(),
        );
      case BuddySortField.diveCount:
        comparison = a.diveCount.compareTo(b.diveCount);
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

/// Apply sorting to a list of buddies (for backward compatibility)
List<Buddy> applyBuddySorting(
  List<Buddy> buddies,
  SortState<BuddySortField> sort,
) {
  final sorted = List<Buddy>.from(buddies);

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A→Z)
    final invertForText = sort.field == BuddySortField.name;

    switch (sort.field) {
      case BuddySortField.name:
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case BuddySortField.diveCount:
        // Dive count not available in basic Buddy entity, sort by name as fallback
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

/// Single buddy provider
final buddyByIdProvider = FutureProvider.family<Buddy?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(buddyRepositoryProvider);
  return repository.getBuddyById(id);
});

/// Buddies for a dive provider
final buddiesForDiveProvider =
    FutureProvider.family<List<BuddyWithRole>, String>((ref, diveId) async {
      final repository = ref.watch(buddyRepositoryProvider);
      return repository.getBuddiesForDive(diveId);
    });

/// Buddy search provider
final buddySearchProvider = FutureProvider.family<List<Buddy>, String>((
  ref,
  query,
) async {
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  if (query.isEmpty) {
    return ref.watch(allBuddiesProvider).value ?? [];
  }
  final repository = ref.watch(buddyRepositoryProvider);
  return repository.searchBuddies(query, diverId: validatedDiverId);
});

/// Buddy stats provider
final buddyStatsProvider = FutureProvider.family<BuddyStats, String>((
  ref,
  buddyId,
) async {
  final repository = ref.watch(buddyRepositoryProvider);
  return repository.getBuddyStats(buddyId);
});

/// Dive IDs for a buddy provider
final diveIdsForBuddyProvider = FutureProvider.family<List<String>, String>((
  ref,
  buddyId,
) async {
  final repository = ref.watch(buddyRepositoryProvider);
  return repository.getDiveIdsForBuddy(buddyId);
});

/// Full dive data for a buddy provider (for display in buddy detail page)
/// Returns the most recent dives first, limited to a reasonable count for preview
final divesForBuddyProvider = FutureProvider.family<List<domain.Dive>, String>((
  ref,
  buddyId,
) async {
  final diveIds = await ref.watch(diveIdsForBuddyProvider(buddyId).future);
  if (diveIds.isEmpty) return [];

  // Fetch full dive data for each ID (limit to first 5 for preview)
  final dives = <domain.Dive>[];
  for (final diveId in diveIds.take(5)) {
    final dive = await ref.watch(diveProvider(diveId).future);
    if (dive != null) {
      dives.add(dive);
    }
  }

  // Sort by date descending (most recent first)
  dives.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return dives;
});

/// Buddy list notifier for mutations
class BuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>> {
  final BuddyRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  BuddyListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allBuddiesProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadBuddies();
  }

  Future<void> _loadBuddies() async {
    state = const AsyncValue.loading();
    try {
      final buddies = await _repository.getAllBuddies(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(buddies);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    // Get fresh validated diver ID before loading
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadBuddies();
    _ref.invalidate(allBuddiesProvider);
  }

  Future<Buddy> addBuddy(Buddy buddy) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final buddyWithDiver = validatedId != null
        ? buddy.copyWith(diverId: validatedId)
        : buddy;
    final newBuddy = await _repository.createBuddy(buddyWithDiver);
    await refresh();
    return newBuddy;
  }

  Future<void> updateBuddy(Buddy buddy) async {
    await _repository.updateBuddy(buddy);
    await refresh();
    _ref.invalidate(buddyByIdProvider(buddy.id));
  }

  Future<void> deleteBuddy(String id) async {
    await _repository.deleteBuddy(id);
    await refresh();
  }
}

final buddyListNotifierProvider =
    StateNotifierProvider<BuddyListNotifier, AsyncValue<List<Buddy>>>((ref) {
      final repository = ref.watch(buddyRepositoryProvider);
      return BuddyListNotifier(repository, ref);
    });

/// Provider to manage buddies for a specific dive during editing
class DiveBuddiesNotifier extends StateNotifier<List<BuddyWithRole>> {
  final BuddyRepository _repository;
  final String? _diveId;

  DiveBuddiesNotifier(this._repository, this._diveId) : super([]) {
    if (_diveId != null) {
      _loadBuddies();
    }
  }

  Future<void> _loadBuddies() async {
    if (_diveId == null) return;
    try {
      final buddies = await _repository.getBuddiesForDive(_diveId);
      state = buddies;
    } catch (e) {
      // Keep empty list on error
      state = [];
    }
  }

  void addBuddy(Buddy buddy, BuddyRole role) {
    // Check if buddy is already added
    final existing = state.indexWhere((b) => b.buddy.id == buddy.id);
    if (existing >= 0) {
      // Update role
      state = [
        ...state.sublist(0, existing),
        BuddyWithRole(buddy: buddy, role: role),
        ...state.sublist(existing + 1),
      ];
    } else {
      state = [...state, BuddyWithRole(buddy: buddy, role: role)];
    }
  }

  void removeBuddy(String buddyId) {
    state = state.where((b) => b.buddy.id != buddyId).toList();
  }

  void updateRole(String buddyId, BuddyRole role) {
    state = state.map((b) {
      if (b.buddy.id == buddyId) {
        return BuddyWithRole(buddy: b.buddy, role: role);
      }
      return b;
    }).toList();
  }

  void clear() {
    state = [];
  }

  void setBuddies(List<BuddyWithRole> buddies) {
    state = buddies;
  }

  Future<void> saveToDatabase(String diveId) async {
    await _repository.setBuddiesForDive(diveId, state);
  }
}

final diveBuddiesNotifierProvider =
    StateNotifierProvider.family<
      DiveBuddiesNotifier,
      List<BuddyWithRole>,
      String?
    >((ref, diveId) {
      final repository = ref.watch(buddyRepositoryProvider);
      return DiveBuddiesNotifier(repository, diveId);
    });
