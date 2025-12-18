import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dive_type_repository.dart';
import '../../domain/entities/dive_type_entity.dart';

/// Repository provider
final diveTypeRepositoryProvider = Provider<DiveTypeRepository>((ref) {
  return DiveTypeRepository();
});

/// All dive types list provider (sorted by sort order, then name)
final diveTypesProvider = FutureProvider<List<DiveTypeEntity>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return repository.getAllDiveTypes();
});

/// Built-in dive types only
final builtInDiveTypesProvider = FutureProvider<List<DiveTypeEntity>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return repository.getBuiltInDiveTypes();
});

/// Custom (user-defined) dive types only
final customDiveTypesProvider = FutureProvider<List<DiveTypeEntity>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return repository.getCustomDiveTypes();
});

/// Single dive type provider
final diveTypeProvider = FutureProvider.family<DiveTypeEntity?, String>((ref, id) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return repository.getDiveTypeById(id);
});

/// Dive type statistics provider
final diveTypeStatisticsProvider = FutureProvider<List<DiveTypeStatistic>>((ref) async {
  final repository = ref.watch(diveTypeRepositoryProvider);
  return repository.getDiveTypeStatistics();
});

/// Dive type list notifier for mutations
class DiveTypeListNotifier extends StateNotifier<AsyncValue<List<DiveTypeEntity>>> {
  final DiveTypeRepository _repository;
  final Ref _ref;

  DiveTypeListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _loadDiveTypes();
  }

  Future<void> _loadDiveTypes() async {
    state = const AsyncValue.loading();
    try {
      final diveTypes = await _repository.getAllDiveTypes();
      state = AsyncValue.data(diveTypes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadDiveTypes();
  }

  /// Add a new custom dive type
  Future<DiveTypeEntity> addDiveType(DiveTypeEntity diveType) async {
    final newDiveType = await _repository.createDiveType(diveType);
    await _loadDiveTypes();
    _ref.invalidate(diveTypesProvider);
    _ref.invalidate(diveTypeStatisticsProvider);
    _ref.invalidate(customDiveTypesProvider);
    return newDiveType;
  }

  /// Add a custom dive type by name (generates ID automatically)
  Future<DiveTypeEntity> addDiveTypeByName(String name) async {
    final diveType = DiveTypeEntity.create(
      id: DiveTypeEntity.generateSlug(name),
      name: name.trim(),
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
