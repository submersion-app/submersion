import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Repository provider
final diverRepositoryProvider = Provider<DiverRepository>((ref) {
  return DiverRepository();
});

/// Diver merge repository provider
final diverMergeRepositoryProvider = Provider<DiverMergeRepository>((ref) {
  return DiverMergeRepository();
});

/// All divers provider.
///
/// A [FutureProvider] that self-invalidates whenever the `divers` table is
/// written (e.g. after a sync), so the list refreshes while imperative
/// `ref.read(allDiversProvider.future)` reads still resolve.
final allDiversProvider = FutureProvider<List<Diver>>((ref) async {
  final repository = ref.watch(diverRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDiversChanges());
  return repository.getAllDivers();
});

/// Duplicate diver groups (same normalized name), surfaced after sync so the
/// user can confirm a merge. Empty when there are no apparent duplicates.
final duplicateDiverGroupsProvider = FutureProvider<List<DuplicateDiverGroup>>((
  ref,
) async {
  final divers = await ref.watch(allDiversProvider.future);
  return DiverMergeRepository.findDuplicateGroups(divers);
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
  ref.invalidateSelfWhen(repository.watchDiversChanges());
  return repository.getDiverById(id);
});

/// Key for storing current diver ID in SharedPreferences.
/// Public so the backup restore flow can sync this value.
const String currentDiverIdKey = 'current_diver_id';

final _activeDiverLog = LoggerService.forClass(CurrentDiverIdNotifier);

/// Resolves the diver id the app should scope to: the first of [candidates]
/// that names an existing diver, else the default diver. Null only when no
/// diver exists at all.
Future<String?> _resolveActiveDiverId(
  DiverRepository repository,
  Iterable<String?> candidates,
) async {
  for (final id in candidates.whereType<String>().toSet()) {
    if (await repository.getDiverById(id) != null) return id;
  }
  return (await repository.getDefaultDiver())?.id;
}

/// After the local database content has been replaced wholesale (backup
/// restore, or adopting a replaced sync library), realign the active diver:
/// validate the restored settings' active diver against the divers table,
/// fall back to the default diver, and persist the result to
/// SharedPreferences so startup picks up the right diver.
///
/// When nothing resolves the stored id is removed rather than left in place.
/// `current_diver_id` lives in SharedPreferences, which a database swap never
/// touches, so a leftover id from the previous library would seed the next
/// launch with a diver that no longer exists and scope every dive query to
/// nothing (issue #1342). With no id the queries run unscoped, which is how
/// every other diver-scoped repository already treats a null diver id.
///
/// Callers that keep running without a restart need not invalidate
/// [currentDiverIdProvider]: the live notifier re-validates itself on the
/// divers-table tick the replace produced.
Future<void> realignActiveDiverAfterDataReplace(SharedPreferences prefs) async {
  try {
    final repository = DiverRepository();
    final resolvedId = await _resolveActiveDiverId(repository, [
      await repository.getActiveDiverIdFromSettings(),
    ]);
    if (resolvedId != null) {
      await prefs.setString(currentDiverIdKey, resolvedId);
    } else if (prefs.containsKey(currentDiverIdKey)) {
      _activeDiverLog.warning(
        'No diver resolves after the data replace; clearing stored active '
        'diver id ${prefs.getString(currentDiverIdKey)}',
      );
      await prefs.remove(currentDiverIdKey);
    }
  } catch (e, stackTrace) {
    // Non-fatal: startup validation in CurrentDiverIdNotifier retries this.
    _activeDiverLog.error(
      'Failed to realign the active diver after the data replace',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

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
  StreamSubscription<void>? _diversChangeSub;

  CurrentDiverIdNotifier(this._prefs, this._repository) : super(null) {
    _loadCurrentDiverId();
    _validateAndSync();
    // A merge, a restore, a replace-adopt, or a sync tombstone can remove the
    // diver this id names without going through setCurrentDiver. Re-validate
    // on the divers-table tick so the live notifier never keeps an id that
    // matches no row (issue #1342). A raw stream subscription rather than a
    // pause-aware ref.listen: the repair must run even while nothing watches
    // this provider, so the next reader gets a healed id.
    try {
      _diversChangeSub = _repository.watchDiversChanges().listen(
        (_) => _validateAndSync(),
      );
    } catch (e, stackTrace) {
      // Same footing as the validation above: without a database (a test
      // that never opened one) the notifier still serves the stored id.
      _activeDiverLog.error(
        'Cannot watch the divers table; the active diver id will not '
        'self-repair until the next launch',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _diversChangeSub?.cancel();
    super.dispose();
  }

  /// Synchronous load from SharedPreferences for immediate UI rendering.
  ///
  /// Unvalidated by design (no DB read is possible synchronously);
  /// [_validateAndSync] follows at once and corrects or clears it.
  void _loadCurrentDiverId() {
    final storedId = _prefs.getString(currentDiverIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      state = storedId;
    }
  }

  /// Async validation, run after construction and again on every divers-table
  /// write. Resolves, in order: the current id if its diver exists, the
  /// Settings-table id (survives a restore) if its diver exists, then the
  /// default diver. Syncs the result to both stores.
  ///
  /// When nothing resolves the id is cleared from state and prefs. A null id
  /// runs the queries unscoped, which is how every other diver-scoped
  /// repository already treats a null diver id; keeping an id that matches no
  /// row would instead scope the logbook to a diver that cannot exist and
  /// empty it for good.
  Future<void> _validateAndSync() async {
    // Everything below awaits; if the user switches diver meanwhile, an
    // answer computed from the old id must not overwrite their choice.
    final startedFrom = state;
    try {
      final dbId = await _repository.getActiveDiverIdFromSettings();
      final resolvedId = await _resolveActiveDiverId(_repository, [
        startedFrom,
        dbId,
      ]);
      if (!mounted || state != startedFrom) return;

      if (resolvedId != startedFrom) {
        if (resolvedId == null) {
          _activeDiverLog.warning(
            'Active diver id $startedFrom matches no diver and none can be '
            'resolved; clearing it',
          );
        } else {
          _activeDiverLog.info(
            'Active diver id resolved to $resolvedId (was $startedFrom)',
          );
        }
        await _persist(resolvedId);
        if (!mounted) return;
        if (state != startedFrom) {
          // The user switched diver while that write was in flight, and
          // their own write may have landed first. Re-persist the newer state
          // so prefs do not keep the answer computed for the old one.
          await _persist(state);
          return;
        }
        state = resolvedId;
      }

      // Keep the DB Settings table in step. Skipped when it already agrees,
      // so a divers-table tick does not turn into a settings write, and left
      // alone when nothing resolved: a stale pointer there is harmless (it is
      // validated on every read) and may name the right diver again once a
      // replace finishes refilling the divers table.
      if (resolvedId != null && dbId != resolvedId) {
        await _repository.setActiveDiverIdInSettings(resolvedId);
      }
    } catch (e, stackTrace) {
      // Not cleared: a failed read says nothing about whether the id is
      // valid. Logged so a transient startup failure that leaves a stale id
      // in place is visible; the next divers-table write retries.
      _activeDiverLog.error(
        'Failed to validate active diver id $startedFrom; keeping it '
        'unvalidated',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _persist(String? id) => id == null
      ? _prefs.remove(currentDiverIdKey)
      : _prefs.setString(currentDiverIdKey, id);

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
  ref.invalidateSelfWhen(repository.watchDiversChanges());

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
  // Widely awaited, so this tick cascades across the app. That is intended and
  // rare: the divers table is written only by diver CRUD and a sync applying
  // one, never by a dive import. Without it, deleting the active diver
  // elsewhere (or a sync doing so) left every diver-scoped query in the app
  // resolving against an id that no longer exists.
  ref.invalidateSelfWhen(repository.watchDiversChanges());

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

    // Refresh when the divers table changes (e.g. a sync writes rows directly).
    final tableChangeSub = _repository.watchDiversChanges().listen(
      (_) => _silentReloadDivers(),
    );
    _ref.onDispose(tableChangeSub.cancel);
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

  /// Reload without flipping to a loading state, so table-driven refreshes
  /// (e.g. after a sync write) do not flash a spinner over existing data.
  Future<void> _silentReloadDivers() async {
    try {
      final divers = await _repository.getAllDivers();
      if (mounted) state = AsyncValue.data(divers);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
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

    // If the deleted diver was current, move the selection to the diver the
    // app would resolve at startup (Settings-table pointer, then default)
    // rather than leaving it null. The notifier's own divers-table tick would
    // repair it eventually, but that races this method's return; resolving
    // here makes the state settled by the time the caller continues.
    final currentId = _ref.read(currentDiverIdProvider);
    if (currentId == id) {
      final replacementId = await _resolveActiveDiverId(_repository, [
        await _repository.getActiveDiverIdFromSettings(),
      ]);
      final notifier = _ref.read(currentDiverIdProvider.notifier);
      if (replacementId != null) {
        await notifier.setCurrentDiver(replacementId);
      } else {
        await notifier.clearCurrentDiver();
      }
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
  ref.invalidateSelfWhen(repository.watchDiversChanges());
  // A junction read over dives.diver_id: a merge or bulk delete changes the
  // count without the divers table being written.
  ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());
  return repository.getDiveCountForDiver(diverId);
});

/// Total bottom time for a specific diver (in seconds)
final diverTotalBottomTimeProvider = FutureProvider.family<int, String>((
  ref,
  diverId,
) async {
  final repository = ref.watch(diverRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDiversChanges());
  ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());
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
  // The stats read the `dives` table, so self-invalidate when dives change
  // (e.g. after a sync) to keep the per-tile counts on the diver list fresh.
  ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());
  final diveCount = await repository.getDiveCountForDiver(diverId);
  final totalTime = await repository.getTotalBottomTimeForDiver(diverId);
  return DiverStats(diveCount: diveCount, totalBottomTimeSeconds: totalTime);
});
