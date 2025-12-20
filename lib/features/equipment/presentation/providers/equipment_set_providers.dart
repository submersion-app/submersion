import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/equipment_set_repository_impl.dart';
import '../../domain/entities/equipment_set.dart';

/// Repository provider
final equipmentSetRepositoryProvider = Provider<EquipmentSetRepository>((ref) {
  return EquipmentSetRepository();
});

/// All equipment sets provider
final equipmentSetsProvider = FutureProvider<List<EquipmentSet>>((ref) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllSets(diverId: validatedDiverId);
});

/// Single equipment set provider (with items populated)
final equipmentSetProvider = FutureProvider.family<EquipmentSet?, String>((ref, id) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  return repository.getSetById(id, includeItems: true);
});

/// Equipment set with items provider (alias for equipmentSetProvider)
final equipmentSetWithItemsProvider = FutureProvider.family<EquipmentSet?, String>((ref, id) async {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  return repository.getSetById(id, includeItems: true);
});

/// Equipment set list notifier for mutations
class EquipmentSetListNotifier extends StateNotifier<AsyncValue<List<EquipmentSet>>> {
  final EquipmentSetRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  EquipmentSetListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
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
    await _loadSets();
    _ref.invalidate(equipmentSetsProvider);
  }

  Future<EquipmentSet> addSet(EquipmentSet set) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new sets
    final setWithDiver = set.diverId == null && validatedId != null
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
}

final equipmentSetListNotifierProvider =
    StateNotifierProvider<EquipmentSetListNotifier, AsyncValue<List<EquipmentSet>>>((ref) {
  final repository = ref.watch(equipmentSetRepositoryProvider);
  return EquipmentSetListNotifier(repository, ref);
});
