import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Repository provider
final diveRoleRepositoryProvider = Provider<DiveRoleRepository>((ref) {
  return DiveRoleRepository();
});

/// All dive roles (built-ins first, then the current diver's custom roles).
///
/// Stays a [FutureProvider] so imperative `ref.read(...future)` reads still
/// resolve, while self-invalidating whenever the `dive_roles` table changes
/// -- including when a sync applies remote changes.
final allDiveRolesProvider = FutureProvider<List<DiveRole>>((ref) async {
  final repository = ref.watch(diveRoleRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchDiveRolesChanges());
  return repository.getAllDiveRoles(diverId: validatedDiverId);
});

/// id -> DiveRole lookup for cheap display resolution.
final diveRoleMapProvider = FutureProvider<Map<String, DiveRole>>((ref) async {
  final roles = await ref.watch(allDiveRolesProvider.future);
  return {for (final role in roles) role.id: role};
});

/// Dive role list notifier for mutations
class DiveRoleListNotifier extends StateNotifier<AsyncValue<List<DiveRole>>> {
  final DiveRoleRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  DiveRoleListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allDiveRolesProvider);
        _initializeAndLoad();
      }
    });

    // Refresh when the dive_roles table changes (e.g. a sync writes rows
    // directly). Cancelled on dispose (provider is autoDispose).
    final tableChangeSub = _repository.watchDiveRolesChanges().listen(
      (_) => _silentReloadDiveRoles(),
    );
    _ref.onDispose(tableChangeSub.cancel);
  }

  Future<void> _initializeAndLoad() async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadDiveRoles();
  }

  Future<void> _loadDiveRoles() async {
    state = const AsyncValue.loading();
    try {
      final roles = await _repository.getAllDiveRoles(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(roles);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reload without flipping to a loading state, so table-driven refreshes
  /// (e.g. after a sync write) do not flash a spinner over existing data.
  Future<void> _silentReloadDiveRoles() async {
    try {
      _validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final roles = await _repository.getAllDiveRoles(
        diverId: _validatedDiverId,
      );
      if (mounted) state = AsyncValue.data(roles);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Add a custom dive role by name. Throws if no valid diver profile exists.
  Future<DiveRole> addDiveRoleByName(String name) async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (validatedId == null) {
      throw Exception('Cannot create custom dive role without a diver profile');
    }
    final created = await _repository.createDiveRole(
      name: name,
      diverId: validatedId,
    );
    await _loadDiveRoles();
    _ref.invalidate(allDiveRolesProvider);
    return created;
  }

  /// Rename an existing custom dive role
  Future<void> renameDiveRole(String id, String name) async {
    await _repository.renameDiveRole(id, name);
    await _loadDiveRoles();
    _ref.invalidate(allDiveRolesProvider);
  }

  /// Delete a custom dive role (built-in roles cannot be deleted)
  Future<void> deleteDiveRole(String id) async {
    await _repository.deleteDiveRole(id);
    await _loadDiveRoles();
    _ref.invalidate(allDiveRolesProvider);
  }

  /// Check if a dive role is referenced by any dive
  Future<bool> isDiveRoleInUse(String id) async {
    return _repository.isDiveRoleInUse(id);
  }
}

final diveRoleListNotifierProvider =
    StateNotifierProvider.autoDispose<
      DiveRoleListNotifier,
      AsyncValue<List<DiveRole>>
    >((ref) {
      final repository = ref.watch(diveRoleRepositoryProvider);
      // Watch the current diver ID so the provider rebuilds when it changes
      ref.watch(currentDiverIdProvider);
      return DiveRoleListNotifier(repository, ref);
    });
