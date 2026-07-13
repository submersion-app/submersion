import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

/// Repository provider
final equipmentSetRepositoryProvider = Provider<EquipmentSetRepository>((ref) {
  return EquipmentSetRepository();
});

/// All equipment sets provider
final equipmentSetsProvider = FutureProvider<List<EquipmentSet>>((ref) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllSets(diverId: validatedDiverId);
});

/// Single equipment set provider (with items populated)
final equipmentSetProvider = FutureProvider.family<EquipmentSet?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  return repository.getSetById(id, includeItems: true, includeGeofences: true);
});

/// Equipment set with items provider (alias for equipmentSetProvider)
final equipmentSetWithItemsProvider =
    FutureProvider.family<EquipmentSet?, String>((ref, id) async {
      final repository = ref.watch(equipmentSetRepositoryProvider);
      return repository.getSetById(id, includeItems: true);
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
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final sets = <EquipmentSet>[];
      for (final base in await repo.getAllSets(diverId: diverId)) {
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

  EquipmentSetListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(equipmentSetsProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
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
  }

  Future<void> clearDefault(String id) async {
    await _repository.clearDefault(id);
    await refresh();
    _ref.invalidate(defaultEquipmentSetProvider);
    _ref.invalidate(equipmentSetSelectionInputsProvider);
  }

  Future<void> addGeofence(EquipmentSetGeofence fence) async {
    await _repository.addGeofence(fence);
    _ref.invalidate(equipmentSetGeofencesProvider(fence.setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
  }

  Future<void> updateGeofence(EquipmentSetGeofence fence) async {
    await _repository.updateGeofence(fence);
    _ref.invalidate(equipmentSetGeofencesProvider(fence.setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
  }

  Future<void> removeGeofence(String setId, String geofenceId) async {
    await _repository.removeGeofence(geofenceId);
    _ref.invalidate(equipmentSetGeofencesProvider(setId));
    _ref.invalidate(equipmentSetSelectionInputsProvider);
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
