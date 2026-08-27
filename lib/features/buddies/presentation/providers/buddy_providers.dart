import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Repository provider
final buddyRepositoryProvider = Provider<BuddyRepository>((ref) {
  return BuddyRepository();
});

/// All buddies provider (filtered by current diver).
///
/// A one-shot read that self-invalidates whenever the `buddies` table changes
/// (a sync apply, a local create/edit/delete, ...), so list UIs refresh
/// automatically while imperative `ref.read(allBuddiesProvider.future)` reads
/// still resolve.
final allBuddiesProvider = FutureProvider<List<Buddy>>((ref) async {
  final repository = ref.watch(buddyRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );

  ref.invalidateSelfWhen(repository.watchBuddiesChanges());

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
      ref.invalidateSelfWhen(repository.watchBuddiesChanges());
      ref.invalidateSelfWhen(
        ref.read(diveRepositoryProvider).watchDivesChanges(),
      );
      return repository.getAllBuddiesWithDiveCount(diverId: validatedDiverId);
    });

/// Search results with dive counts, for the "Add buddy" picker sheet, which
/// sorts by dive count and needs that even while a search query is active.
final buddySearchWithDiveCountProvider =
    FutureProvider.family<List<BuddyWithDiveCount>, String>((ref, query) async {
      if (query.isEmpty) {
        return ref.watch(allBuddiesWithDiveCountProvider).value ?? [];
      }
      final repository = ref.watch(buddyRepositoryProvider);
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      ref.invalidateSelfWhen(repository.watchBuddiesChanges());
      return repository.getAllBuddiesWithDiveCount(
        diverId: validatedDiverId,
        query: query,
      );
    });

/// Sort state for the "Add buddy" picker sheet. Defaults to dive count
/// descending (issue #638): divers with many buddies on file mostly care
/// about who they dive with often, not the full alphabet.
final buddyPickerSortProvider = StateProvider<SortState<BuddySortField>>(
  (ref) => const SortState(
    field: BuddySortField.diveCount,
    direction: SortDirection.descending,
  ),
);

/// Apply sorting to a list of buddies with dive counts
List<BuddyWithDiveCount> applyBuddyWithDiveCountSorting(
  List<BuddyWithDiveCount> buddies,
  SortState<BuddySortField> sort,
) {
  final sorted = List<BuddyWithDiveCount>.from(buddies);

  int byNameAscending(BuddyWithDiveCount a, BuddyWithDiveCount b) =>
      a.buddy.name.toLowerCase().compareTo(b.buddy.name.toLowerCase());

  sorted.sort((a, b) {
    switch (sort.field) {
      case BuddySortField.name:
        final comparison = byNameAscending(a, b);
        // For text fields, invert direction (user expects descending = A→Z)
        return sort.direction == SortDirection.ascending
            ? -comparison
            : comparison;
      case BuddySortField.diveCount:
        final comparison = a.diveCount.compareTo(b.diveCount);
        if (comparison == 0) {
          // Ties (very common -- most buddies share 0 dives) break
          // alphabetically, so the order is deterministic instead of left to
          // an unstable sort.
          return byNameAscending(a, b);
        }
        return sort.direction == SortDirection.ascending
            ? comparison
            : -comparison;
    }
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
  ref.invalidateSelfWhen(repository.watchBuddiesChanges());
  return repository.getBuddyById(id);
});

/// Buddies for a dive provider
final buddiesForDiveProvider =
    FutureProvider.family<List<BuddyWithRole>, String>((ref, diveId) async {
      final repository = ref.watch(buddyRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
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
  ref.invalidateSelfWhen(repository.watchBuddiesChanges());
  return repository.searchBuddies(query, diverId: validatedDiverId);
});

/// Buddy stats provider.
///
/// Aggregates the buddy's dives, so it takes the dives tick as well as the
/// buddies tick. Without it the buddy detail header's dive count and the dive
/// list beneath it disagreed after a merge: the list was reactive, the count
/// was not (issue #974, same shape as #958 and #970).
final buddyStatsProvider = FutureProvider.family<BuddyStats, String>((
  ref,
  buddyId,
) async {
  final repository = ref.watch(buddyRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchBuddiesChanges());
  ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());
  return repository.getBuddyStats(buddyId);
});

/// Dive IDs for a buddy provider.
///
/// A junction read: the ids come from `dive_buddies`, whose rows vanish by
/// cascade when a dive is deleted, so the `buddies` table is never written and
/// its tick alone would miss the change.
final diveIdsForBuddyProvider = FutureProvider.family<List<String>, String>((
  ref,
  buddyId,
) async {
  final repository = ref.watch(buddyRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchBuddiesChanges());
  ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());
  return repository.getDiveIdsForBuddy(buddyId);
});

/// How many shared dives the buddy detail page previews before the caller has
/// to tap "view all".
const buddySharedDivePreviewLimit = 5;

/// Full dive data for a buddy provider (for display in buddy detail page)
///
/// Returns the most recent dives first, limited to a reasonable count for
/// preview. [diveIdsForBuddyProvider] already orders by dive date descending,
/// so truncating to the preview limit keeps the newest dives; the Dart sort
/// below only re-asserts that order over the hydrated entities.
final divesForBuddyProvider = FutureProvider.family<List<domain.Dive>, String>((
  ref,
  buddyId,
) async {
  final diveIds = await ref.watch(diveIdsForBuddyProvider(buddyId).future);
  if (diveIds.isEmpty) return [];

  final dives = <domain.Dive>[];
  for (final diveId in diveIds.take(buddySharedDivePreviewLimit)) {
    final dive = await ref.watch(diveProvider(diveId).future);
    if (dive != null) {
      dives.add(dive);
    }
  }

  dives.sort(compareSharedDivesForPreview);
  return dives;
});

/// Orders two shared dives exactly as `BuddyRepository.getDiveIdsForBuddy`
/// does: newest effective entry time first, then dive number descending, then
/// id ascending.
///
/// The dive-number step is null-aware rather than coalescing to zero. SQLite
/// sorts NULL below every value, so `ORDER BY dive_number DESC` puts a null
/// dive number *last*, behind a real `0` or a negative one. Coalescing to zero
/// would instead tie a null with a real zero and rank it above a negative,
/// which would reorder the list the repository already ordered.
int compareSharedDivesForPreview(domain.Dive a, domain.Dive b) {
  final byTime = b.effectiveEntryTime.compareTo(a.effectiveEntryTime);
  if (byTime != 0) return byTime;

  final aNumber = a.diveNumber;
  final bNumber = b.diveNumber;
  if (aNumber != bNumber) {
    if (aNumber == null) return 1;
    if (bNumber == null) return -1;
    return bNumber.compareTo(aNumber);
  }

  return a.id.compareTo(b.id);
}

/// Buddy list notifier for mutations
class BuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>> {
  final BuddyRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  BuddyListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    logFailure(_initializeAndLoad(), BuddyListNotifier, 'initialize and load');

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allBuddiesProvider);
        logFailure(
          _initializeAndLoad(),
          BuddyListNotifier,
          'initialize and load',
        );
      }
    });

    // Reload when the `buddies` table changes (e.g. a sync writes rows
    // directly) so surfaces watching this notifier (e.g. the buddy summary)
    // refresh too.
    final tableChangeSub = _repository.watchBuddiesChanges().listen(
      (_) => _silentReloadBuddies(),
    );
    _ref.onDispose(tableChangeSub.cancel);
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

  /// Reload without flipping to a loading state, for table-change ticks (e.g.
  /// a sync). Resolves the validated diver id first so an early tick scopes
  /// correctly.
  Future<void> _silentReloadBuddies() async {
    try {
      _validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final buddies = await _repository.getAllBuddies(
        diverId: _validatedDiverId,
      );
      if (mounted) state = AsyncValue.data(buddies);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
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
    _ref.invalidate(buddyByIdProvider(id));
    _ref.invalidate(allBuddiesWithDiveCountProvider);
    await refresh();
  }

  /// Toggle favorite status for a buddy (issue #638)
  Future<void> toggleFavorite(String buddyId) async {
    await _repository.toggleFavorite(buddyId);
    _ref.invalidate(buddyByIdProvider(buddyId));
    _ref.invalidate(allBuddiesWithDiveCountProvider);
    await refresh();
  }

  Future<BuddyMergeSnapshot?> mergeBuddies(
    Buddy mergedBuddy,
    List<String> buddyIds,
  ) async {
    if (buddyIds.length < 2) return null;

    final dedupedIds = buddyIds.toSet().toList(growable: false);
    final survivorId = dedupedIds.first;

    final result = await _repository.mergeBuddies(
      mergedBuddy: mergedBuddy.copyWith(id: survivorId),
      buddyIds: dedupedIds,
    );

    await _invalidateMergeProviders(dedupedIds);
    await refresh();

    return result?.snapshot;
  }

  Future<void> undoMerge(BuddyMergeSnapshot snapshot) async {
    await _repository.undoMerge(snapshot);
    final affectedIds = [
      snapshot.originalSurvivor.id,
      ...snapshot.deletedBuddies.map((b) => b.id),
    ];
    await _invalidateMergeProviders(affectedIds);
    await refresh();
  }

  Future<void> bulkDeleteBuddies(List<String> ids) async {
    await _repository.bulkDeleteBuddies(ids);
    for (final id in ids) {
      _ref.invalidate(buddyByIdProvider(id));
    }
    _ref.invalidate(allBuddiesWithDiveCountProvider);
    await refresh();
  }

  Future<void> _invalidateMergeProviders(List<String> buddyIds) async {
    _ref.invalidate(allBuddiesProvider);
    _ref.invalidate(allBuddiesWithDiveCountProvider);
    for (final id in buddyIds) {
      _ref.invalidate(buddyByIdProvider(id));
      _ref.invalidate(buddyStatsProvider(id));
      final diveIds = await _repository.getDiveIdsForBuddy(id);
      for (final diveId in diveIds) {
        _ref.invalidate(buddiesForDiveProvider(diveId));
      }
      _ref.invalidate(diveIdsForBuddyProvider(id));
      _ref.invalidate(divesForBuddyProvider(id));
    }
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

  void addBuddy(Buddy buddy, DiveRole role) {
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

  void updateRole(String buddyId, DiveRole role) {
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

// ============================================================================
// Buddy Highlighted ID (for table mode detail pane)
// ============================================================================

/// Tracks the currently highlighted buddy. Used by the table's row highlight
/// and by the phone-mode list to tint the last-visited buddy card on return
/// from the detail page.
final highlightedBuddyIdProvider = StateProvider<String?>((ref) => null);

// ============================================================================
// Buddy Table View Config
// ============================================================================

/// Provider for the buddy table view column configuration.
///
/// Persists column visibility, order, widths, and sort state per diver using
/// [ViewConfigRepository] under the key 'table_buddies'.
final buddyTableConfigProvider =
    StateNotifierProvider<
      EntityTableConfigNotifier<BuddyField>,
      EntityTableViewConfig<BuddyField>
    >((ref) {
      final notifier = EntityTableConfigNotifier<BuddyField>(
        defaultConfig: EntityTableViewConfig<BuddyField>(
          columns: [
            EntityTableColumnConfig(
              field: BuddyField.buddyName,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: BuddyField.certificationLevel),
            EntityTableColumnConfig(field: BuddyField.certificationAgency),
            EntityTableColumnConfig(field: BuddyField.email),
            EntityTableColumnConfig(field: BuddyField.diveCount),
          ],
        ),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'table_buddies');
      }
      return notifier;
    });

// ============================================================================
// Buddy Card View Config
// ============================================================================

/// Detailed buddy card slots. Persisted per diver under
/// `card_detailed_buddies`.
final buddyDetailedCardConfigProvider =
    StateNotifierProvider<
      EntityCardConfigNotifier<BuddyField>,
      EntityCardViewConfig<BuddyField>
    >((ref) {
      final notifier = EntityCardConfigNotifier<BuddyField>(
        defaultConfig: const EntityCardViewConfig<BuddyField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
            EntityCardSlotConfig(slotId: 'subtitle', field: BuddyField.email),
            EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
            EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
          ],
        ),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'card_detailed_buddies');
      }
      return notifier;
    });

/// Compact buddy card slots. Persisted per diver under `card_compact_buddies`.
final buddyCompactCardConfigProvider =
    StateNotifierProvider<
      EntityCardConfigNotifier<BuddyField>,
      EntityCardViewConfig<BuddyField>
    >((ref) {
      final notifier = EntityCardConfigNotifier<BuddyField>(
        defaultConfig: const EntityCardViewConfig<BuddyField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
            EntityCardSlotConfig(
              slotId: 'subtitle',
              field: BuddyField.certificationLevel,
            ),
            EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
            EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
          ],
        ),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'card_compact_buddies');
      }
      return notifier;
    });
