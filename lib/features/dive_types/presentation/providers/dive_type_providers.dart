import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/dive_type_repository.dart';
import '../../domain/entities/dive_type_entity.dart';

/// Repository provider
final diveTypeRepositoryProvider = Provider<DiveTypeRepository>((ref) {
  return DiveTypeRepository();
});

/// All dive types list provider (sorted by sort order, then name)
/// Includes built-in types plus custom types for the current diver
final diveTypesProvider = FutureProvider<List<DiveTypeEntity>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllDiveTypes(diverId: validatedDiverId);
});

/// Built-in dive types only
final builtInDiveTypesProvider = FutureProvider<List<DiveTypeEntity>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return repository.getBuiltInDiveTypes();
});

/// Custom (user-defined) dive types only for the current diver
final customDiveTypesProvider = FutureProvider<List<DiveTypeEntity>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getCustomDiveTypes(diverId: validatedDiverId);
});

/// Single dive type provider
final diveTypeProvider = FutureProvider.family<DiveTypeEntity?, String>((ref, id) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return repository.getDiveTypeById(id);
});

/// Dive type statistics provider for the current diver
final diveTypeStatisticsProvider = FutureProvider<List<DiveTypeStatistic>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getDiveTypeStatistics(diverId: validatedDiverId);
});

/// Dive type list notifier for mutations
class DiveTypeListNotifier extends StateNotifier<AsyncValue<List<DiveTypeEntity>>> {
  final DiveTypeRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  DiveTypeListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    // Get validated diver ID (falls back to default if current doesn't exist)
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadDiveTypes();
  }

  Future<void> _loadDiveTypes() async {
    state = const AsyncValue.loading();
    try {
      final diveTypes = await _repository.getAllDiveTypes(diverId: _validatedDiverId);
      state = AsyncValue.data(diveTypes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadDiveTypes();
    _ref.invalidate(diveTypesProvider);
  }

  /// Add a new custom dive type
  Future<DiveTypeEntity> addDiveType(DiveTypeEntity diveType) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new custom dive types
    final diveTypeWithDiver = diveType.diverId == null && validatedId != null
        ? diveType.copyWith(diverId: validatedId)
        : diveType;
    final newDiveType = await _repository.createDiveType(diveTypeWithDiver);
    await _loadDiveTypes();
    _ref.invalidate(diveTypesProvider);
    _ref.invalidate(diveTypeStatisticsProvider);
    _ref.invalidate(customDiveTypesProvider);
    return newDiveType;
  }

  /// Add a custom dive type by name (generates ID automatically)
  Future<DiveTypeEntity> addDiveTypeByName(String name) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    final diveType = DiveTypeEntity.create(
      id: DiveTypeEntity.generateSlug(name),
      name: name.trim(),
      diverId: validatedId,
    );
    return addDiveType(diveType);
  }

  /// Update an existing custom dive type
  Future<void> updateDiveType(DiveTypeEntity diveType) async {
    await _repository.updateDiveType(diveType);
    await _loadDiveTypes();
    _ref.invalidate(diveTypesProvider);
    _ref.invalidate(diveTypeStatisticsProvider);
    _ref.invalidate(customDiveTypesProvider);
  }

  /// Delete a custom dive type (built-in types cannot be deleted)
  Future<void> deleteDiveType(String id) async {
    await _repository.deleteDiveType(id);
    await _loadDiveTypes();
    _ref.invalidate(diveTypesProvider);
    _ref.invalidate(diveTypeStatisticsProvider);
    _ref.invalidate(customDiveTypesProvider);
  }

  /// Check if a dive type is in use
  Future<bool> isDiveTypeInUse(String id) async {
    return _repository.isDiveTypeInUse(id);
  }
}

final diveTypeListNotifierProvider =
    StateNotifierProvider<DiveTypeListNotifier, AsyncValue<List<DiveTypeEntity>>>((ref) {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return DiveTypeListNotifier(repository, ref);
});
