import 'dart:async';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Repository provider
final equipmentSetRepositoryProvider = Provider<EquipmentSetRepository>((ref) {
  return EquipmentSetRepository();
});

/// All equipment sets provider.
///
/// Self-invalidates on [EquipmentSetRepository.watchSetChanges] so a set's
/// membership never outlives the gear it points at -- deleting an equipment
/// item cascades its junction rows away, and a cached set carrying the dead id
/// used to break the next save (issue #819). The stream also covers writes that
/// bypass the notifier entirely (sync, imports, dive-computer downloads).
final equipmentSetsProvider = FutureProvider<List<EquipmentSet>>((ref) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchSetChanges());
  return repository.getAllSets(diverId: validatedDiverId);
});

/// Single equipment set provider (with items and geofences populated).
///
/// Self-invalidates on the same change tick as [equipmentSetsProvider]; see
/// that provider for why.
final equipmentSetProvider = FutureProvider.family<EquipmentSet?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchSetChanges());
  return repository.getSetById(id, includeItems: true, includeGeofences: true);
});

/// Equipment set with items populated.
///
/// Delegates to [equipmentSetProvider] rather than issuing its own query: as a
/// separate provider it had a separate cache that nothing ever invalidated, so
/// consumers such as the dive-log "use set" picker could render membership that
/// was stale by an arbitrary amount. Geofences ride along unused, which costs
/// one extra small query on a cache miss and buys a single source of truth.
final equipmentSetWithItemsProvider =
    FutureProvider.family<EquipmentSet?, String>((ref, id) async {
      return ref.watch(equipmentSetProvider(id).future);
    });

/// The active diver's default equipment set, or null.
final defaultEquipmentSetProvider = FutureProvider<EquipmentSet?>((ref) async {
  final sets = await ref.watch(equipmentSetsProvider.future);
  for (final s in sets) {
    if (s.isDefault) {
      return ref.watch(equipmentSetWithItemsProvider(s.id).future);
    }
  }
  return null;
});

/// Geofences for a single set.
final equipmentSetGeofencesProvider =
    FutureProvider.family<List<EquipmentSetGeofence>, String>((
      ref,
      setId,
    ) async {
      final repo = ref.watch(equipmentSetRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchSetChanges());
      return repo.getGeofencesForSet(setId);
    });

/// Immutable bundle the selector needs for the active diver.
class EquipmentSetSelectionInputs {
  final List<EquipmentSet> sets;
  final List<EquipmentSetGeofence> geofences;
  const EquipmentSetSelectionInputs({
    required this.sets,
    required this.geofences,
  });
}

/// The active diver's sets (with items) + all their geofences, ready for the
/// selector.
final equipmentSetSelectionInputsProvider =
    FutureProvider<EquipmentSetSelectionInputs>((ref) async {
      final repo = ref.watch(equipmentSetRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchSetChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      // Depend on equipmentSetsProvider so every set/item mutation (which
      // invalidates it via the notifier's refresh) rebuilds this bundle too;
      // otherwise a deleted or edited set could still be auto-applied to a new
      // dive. Geofence-only mutations additionally invalidate this provider
      // directly, since they do not touch equipmentSetsProvider.
      final baseSets = await ref.watch(equipmentSetsProvider.future);
      final sets = <EquipmentSet>[];
      for (final base in baseSets) {
        sets.add((await repo.getSetById(base.id, includeItems: true)) ?? base);
      }
      final geofences = await repo.getAllGeofences(diverId: diverId);
      return EquipmentSetSelectionInputs(sets: sets, geofences: geofences);
    });

/// Equipment set list notifier for mutations
class EquipmentSetListNotifier
    extends StateNotifier<AsyncValue<List<EquipmentSet>>> {
  final EquipmentSetRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  /// True once the validated diver id has been read at least once; guards
  /// the reactive reload against the "null means unfiltered" startup window.
  bool _diverResolved = false;

  StreamSubscription<void>? _changeSub;

  EquipmentSetListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    logFailure(
      _initializeAndLoad(),
      EquipmentSetListNotifier,
      'initialize and load',
    );

    // A StateNotifier cannot self-invalidate the way the FutureProviders above
    // do, and the sets list renders itemCount straight off equipmentIds -- so
    // without this a deleted gear item left the list showing a stale member
    // count until a manual pull-to-refresh (issue #819). Reload in place rather
    // than through _loadSets so the list does not flash a spinner on every tick.
    _changeSub = _repository.watchSetChanges().listen((_) {
      if (mounted) _reloadSetsPreservingState();
    });

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(equipmentSetsProvider);
        logFailure(
          _initializeAndLoad(),
          EquipmentSetListNotifier,
          'initialize and load',
        );
      }
    });
  }

  @override
  void dispose() {
    _changeSub?.cancel();
    super.dispose();
  }

  /// Re-reads the sets without dropping to [AsyncValue.loading] first, so a
  /// background change tick refreshes the rendered list instead of blanking it.
  ///
  /// Skipped until the diver id has resolved once: a null [_validatedDiverId]
  /// means "no filter", so an early tick would briefly publish every diver's
  /// sets. The pending [_initializeAndLoad] covers that window.
  Future<void> _reloadSetsPreservingState() async {
    if (!_diverResolved) return;
    try {
      final sets = await _repository.getAllSets(diverId: _validatedDiverId);
      if (mounted) state = AsyncValue.data(sets);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    _diverResolved = true;
    await _loadSets();
  }

  Future<void> _loadSets() async {
    state = const AsyncValue.loading();
    try {
      final sets = await _repository.getAllSets(diverId: _validatedDiverId);
      state = AsyncValue.data(sets);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    // Get fresh validated diver ID before loading
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    _diverResolved = true;
    await _loadSets();
    _ref.invalidate(equipmentSetsProvider);
  }

  Future<EquipmentSet> addSet(EquipmentSet set) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final setWithDiver = validatedId != null
        ? set.copyWith(diverId: validatedId)
        : set;
    final newSet = await _repository.createSet(setWithDiver);
    await refresh();
    return newSet;
  }

  Future<void> updateSet(EquipmentSet set) async {
    await _repository.updateSet(set);
    await refresh();
    _ref.invalidate(equipmentSetsProvider);
    _ref.invalidate(equipmentSetProvider(set.id));
  }

  Future<void> deleteSet(String id) async {
    await _repository.deleteSet(id);
    await refresh();
    _ref.invalidate(equipmentSetsProvider);
  }

  Future<void> addItemToSet(String setId, String equipmentId) async {
    await _repository.addItemToSet(setId, equipmentId);
    await refresh();
    _ref.invalidate(equipmentSetProvider(setId));
  }

  Future<void> removeItemFromSet(String setId, String equipmentId) async {
    await _repository.removeItemFromSet(setId, equipmentId);
    await refresh();
    _ref.invalidate(equipmentSetProvider(setId));
  }

  Future<void> setAsDefault(String id) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    await _repository.setAsDefault(id, diverId: diverId);
    await refresh();
    _ref.invalidate(defaultEquipmentSetProvider);
    _ref.invalidate(equipmentSetSelectionInputsProvider);
    // Promoting one set demotes the previous default, so the hydrated
    // isDefault flag on more than one family instance is now stale. Invalidate
    // the whole family so open detail/edit pages re-read the correct badge.
    _ref.invalidate(equipmentSetProvider);
  }

  Future<void> clearDefault(String id) async {
    await _repository.clearDefault(id);
    await refresh();
    _ref.invalidate(defaultEquipmentSetProvider);
    _ref.invalidate(equipmentSetSelectionInputsProvider);
    _ref.invalidate(equipmentSetProvider(id));
  }

  Future<void> addGeofence(EquipmentSetGeofence fence) async {
    await _repository.addGeofence(fence);
    _ref.invalidate(equipmentSetGeofencesProvider(fence.setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
    // equipmentSetProvider hydrates geofences, so its cache is now stale.
    _ref.invalidate(equipmentSetProvider(fence.setId));
  }

  Future<void> updateGeofence(EquipmentSetGeofence fence) async {
    await _repository.updateGeofence(fence);
    _ref.invalidate(equipmentSetGeofencesProvider(fence.setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
    _ref.invalidate(equipmentSetProvider(fence.setId));
  }

  Future<void> removeGeofence(String setId, String geofenceId) async {
    await _repository.removeGeofence(geofenceId);
    _ref.invalidate(equipmentSetGeofencesProvider(setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
    _ref.invalidate(equipmentSetProvider(setId));
  }
}

final equipmentSetListNotifierProvider =
    StateNotifierProvider<
      EquipmentSetListNotifier,
      AsyncValue<List<EquipmentSet>>
    >((ref) {
      final repository = ref.watch(equipmentSetRepositoryProvider);
      return EquipmentSetListNotifier(repository, ref);
    });
