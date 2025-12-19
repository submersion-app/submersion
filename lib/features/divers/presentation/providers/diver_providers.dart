import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/repositories/diver_repository.dart';
import '../../domain/entities/diver.dart';

/// Repository provider
final diverRepositoryProvider = Provider<DiverRepository>((ref) {
  return DiverRepository();
});

/// All divers provider
final allDiversProvider = FutureProvider<List<Diver>>((ref) async {
  final repository = ref.watch(diverRepositoryProvider);
  return repository.getAllDivers();
});

/// Single diver provider
final diverByIdProvider =
    FutureProvider.family<Diver?, String>((ref, id) async {
  final repository = ref.watch(diverRepositoryProvider);
  return repository.getDiverById(id);
});

/// Key for storing current diver ID in SharedPreferences
const String _currentDiverIdKey = 'current_diver_id';

/// Current diver ID provider (persisted)
final currentDiverIdProvider =
    StateNotifierProvider<CurrentDiverIdNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CurrentDiverIdNotifier(prefs);
});

class CurrentDiverIdNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;

  CurrentDiverIdNotifier(this._prefs) : super(null) {
    _loadCurrentDiverId();
  }

  void _loadCurrentDiverId() {
    final storedId = _prefs.getString(_currentDiverIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      state = storedId;
    }
  }

  Future<void> setCurrentDiver(String diverId) async {
    await _prefs.setString(_currentDiverIdKey, diverId);
    state = diverId;
  }

  Future<void> clearCurrentDiver() async {
    await _prefs.remove(_currentDiverIdKey);
    state = null;
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

  Future<void> deleteDiver(String id) async {
    await _repository.deleteDiver(id);
    await refresh();

    // If deleted diver was current, clear selection
    final currentId = _ref.read(currentDiverIdProvider);
    if (currentId == id) {
      await _ref.read(currentDiverIdProvider.notifier).clearCurrentDiver();
    }
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
final diverDiveCountProvider =
    FutureProvider.family<int, String>((ref, diverId) async {
  final repository = ref.watch(diverRepositoryProvider);
  return repository.getDiveCountForDiver(diverId);
});

/// Total bottom time for a specific diver (in seconds)
final diverTotalBottomTimeProvider =
    FutureProvider.family<int, String>((ref, diverId) async {
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

final diverStatsProvider =
    FutureProvider.family<DiverStats, String>((ref, diverId) async {
  final repository = ref.watch(diverRepositoryProvider);
  final diveCount = await repository.getDiveCountForDiver(diverId);
  final totalTime = await repository.getTotalBottomTimeForDiver(diverId);
  return DiverStats(
    diveCount: diveCount,
    totalBottomTimeSeconds: totalTime,
  );
});
