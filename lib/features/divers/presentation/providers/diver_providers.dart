import 'package:submersion/core/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// Repository provider
final diverRepositoryProvider = Provider<DiverRepository>((ref) {
  return DiverRepository();
});

/// All divers provider
final allDiversProvider = FutureProvider<List<Diver>>((ref) async {
  final repository = ref.watch(diverRepositoryProvider);
  return repository.getAllDivers();
});

/// Check if any diver profiles exist
final hasAnyDiversProvider = FutureProvider<bool>((ref) async {
  final divers = await ref.watch(allDiversProvider.future);
  return divers.isNotEmpty;
});

/// Single diver provider
final diverByIdProvider = FutureProvider.family<Diver?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(diverRepositoryProvider);
  return repository.getDiverById(id);
});

/// Key for storing current diver ID in SharedPreferences.
/// Public so the backup restore flow can sync this value.
const String currentDiverIdKey = 'current_diver_id';

/// Current diver ID provider (persisted to both SharedPreferences and DB)
final currentDiverIdProvider =
    StateNotifierProvider<CurrentDiverIdNotifier, String?>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final repository = ref.watch(diverRepositoryProvider);
      return CurrentDiverIdNotifier(prefs, repository);
    });

class CurrentDiverIdNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  final DiverRepository _repository;

  CurrentDiverIdNotifier(this._prefs, this._repository) : super(null) {
    _loadCurrentDiverId();
    _validateAndSync();
  }

  /// Synchronous load from SharedPreferences for immediate UI rendering.
  void _loadCurrentDiverId() {
    final storedId = _prefs.getString(currentDiverIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      state = storedId;
    }
  }

  /// Async validation that runs after construction.
  /// Checks the prefs ID is valid, falls back to DB Settings table,
  /// then to default diver. Syncs resolved ID back to both stores.
  Future<void> _validateAndSync() async {
    try {
      String? resolvedId = state;

      // Check if the prefs ID actually exists in the divers table
      if (resolvedId != null) {
        final diver = await _repository.getDiverById(resolvedId);
        if (diver == null) {
          resolvedId = null;
        }
      }

      // If prefs ID was stale/empty, try the Settings table (survives restore)
      if (resolvedId == null) {
        final dbId = await _repository.getActiveDiverIdFromSettings();
        if (dbId != null) {
          final diver = await _repository.getDiverById(dbId);
          if (diver != null) {
            resolvedId = dbId;
          }
        }
      }

      // Last resort: fall back to the default diver
      if (resolvedId == null) {
        final defaultDiver = await _repository.getDefaultDiver();
        resolvedId = defaultDiver?.id;
      }

      // Sync the resolved ID to both stores if it changed
      if (resolvedId != null && resolvedId != state) {
        await _prefs.setString(currentDiverIdKey, resolvedId);
        state = resolvedId;
      }

      // Ensure the DB Settings table is in sync
      if (resolvedId != null) {
        await _repository.setActiveDiverIdInSettings(resolvedId);
      }
    } catch (_) {
      // Non-fatal: SharedPreferences remains the primary source
    }
  }

  Future<void> setCurrentDiver(String diverId) async {
    await _prefs.setString(currentDiverIdKey, diverId);
    state = diverId;
    // Fire-and-forget DB write
    _repository.setActiveDiverIdInSettings(diverId);
  }

  Future<void> clearCurrentDiver() async {
    await _prefs.remove(currentDiverIdKey);
    state = null;
    // Fire-and-forget DB write
    _repository.setActiveDiverIdInSettings(null);
  }
}

/// Current diver entity provider (resolves ID to full entity)
final currentDiverProvider = FutureProvider<Diver?>((ref) async {
  final currentId = ref.watch(currentDiverIdProvider);
  final repository = ref.watch(diverRepositoryProvider);

  if (currentId != null) {
    final diver = await repository.getDiverById(currentId);
    if (diver != null) return diver;
  }

  // Fallback to default diver
  return repository.getDefaultDiver();
});

/// Validated current diver ID provider
/// Returns the current diver ID only if it exists in the database,
/// otherwise returns the default diver ID
final validatedCurrentDiverIdProvider = FutureProvider<String?>((ref) async {
  final currentId = ref.watch(currentDiverIdProvider);
  final repository = ref.watch(diverRepositoryProvider);

  if (currentId != null) {
    final diver = await repository.getDiverById(currentId);
    if (diver != null) return currentId;
  }

  // Fallback to default diver's ID
  final defaultDiver = await repository.getDefaultDiver();
  return defaultDiver?.id;
});

/// Diver list notifier for mutations
class DiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>> {
  final DiverRepository _repository;
  final Ref _ref;

  DiverListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _loadDivers();
  }

  Future<void> _loadDivers() async {
    state = const AsyncValue.loading();
    try {
      final divers = await _repository.getAllDivers();
      state = AsyncValue.data(divers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadDivers();
    _ref.invalidate(allDiversProvider);
    _ref.invalidate(currentDiverProvider);
  }

  Future<Diver> addDiver(Diver diver) async {
    final newDiver = await _repository.createDiver(diver);
    await refresh();
    return newDiver;
  }

  Future<void> updateDiver(Diver diver) async {
    await _repository.updateDiver(diver);
    await refresh();
    _ref.invalidate(diverByIdProvider(diver.id));
  }

  Future<DeleteDiverResult> deleteDiver(String id) async {
    final result = await _repository.deleteDiverWithReassignment(id);
    await refresh();

    // If deleted diver was current, clear selection
    final currentId = _ref.read(currentDiverIdProvider);
    if (currentId == id) {
      await _ref.read(currentDiverIdProvider.notifier).clearCurrentDiver();
    }
    return result;
  }

  Future<void> setAsDefault(String id) async {
    await _repository.setDefaultDiver(id);
    await refresh();
  }
}

final diverListNotifierProvider =
    StateNotifierProvider<DiverListNotifier, AsyncValue<List<Diver>>>((ref) {
      final repository = ref.watch(diverRepositoryProvider);
      return DiverListNotifier(repository, ref);
    });

/// Dive count for a specific diver
final diverDiveCountProvider = FutureProvider.family<int, String>((
  ref,
  diverId,
) async {
  final repository = ref.watch(diverRepositoryProvider);
  return repository.getDiveCountForDiver(diverId);
});

/// Total bottom time for a specific diver (in seconds)
final diverTotalBottomTimeProvider = FutureProvider.family<int, String>((
  ref,
  diverId,
) async {
  final repository = ref.watch(diverRepositoryProvider);
  return repository.getTotalBottomTimeForDiver(diverId);
});

/// Diver statistics summary
class DiverStats {
  final int diveCount;
  final int totalBottomTimeSeconds;

  const DiverStats({
    required this.diveCount,
    required this.totalBottomTimeSeconds,
  });

  String get formattedBottomTime {
    final hours = totalBottomTimeSeconds ~/ 3600;
    final minutes = (totalBottomTimeSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

final diverStatsProvider = FutureProvider.family<DiverStats, String>((
  ref,
  diverId,
) async {
  final repository = ref.watch(diverRepositoryProvider);
  final diveCount = await repository.getDiveCountForDiver(diverId);
  final totalTime = await repository.getTotalBottomTimeForDiver(diverId);
  return DiverStats(diveCount: diveCount, totalBottomTimeSeconds: totalTime);
});
