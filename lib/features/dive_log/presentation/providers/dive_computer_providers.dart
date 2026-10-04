import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/domain/services/dive_computer_merge_rules.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Repository provider for dive computers
final diveComputerRepositoryProvider = Provider<DiveComputerRepository>((ref) {
  return DiveComputerRepository();
});

/// Repository provider for folding duplicate dive computer records together.
final diveComputerMergeRepositoryProvider =
    Provider<DiveComputerMergeRepository>((ref) {
      return DiveComputerMergeRepository();
    });

/// All dive computers
final allDiveComputersProvider = FutureProvider<List<DiveComputer>>((
  ref,
) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchComputersChanges());
  return repository.getAllComputers(diverId: validatedDiverId);
});

/// Lookup map of saved dive computers keyed by Bluetooth address.
///
/// Used by the discovery wizard to show serial number and firmware version
/// for previously-downloaded devices during scan and confirm steps.
final savedComputersByAddressProvider =
    FutureProvider<Map<String, DiveComputer>>((ref) async {
      final computers = await ref.watch(allDiveComputersProvider.future);
      final map = <String, DiveComputer>{};
      for (final computer in computers) {
        if (computer.bluetoothAddress != null) {
          map[computer.bluetoothAddress!] = computer;
        }
      }
      return map;
    });

/// Get a dive computer by ID
final diveComputerByIdProvider = FutureProvider.family<DiveComputer?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchComputersChanges());
  return repository.getComputerById(id);
});

/// Other saved computers that look like the same physical device as [id]:
/// a shared serial number with a compatible manufacturer and model (#645).
///
/// Empty when the computer is unknown or has no serial number to compare on.
final possibleDuplicateComputersProvider =
    FutureProvider.family<List<DiveComputer>, String>((ref, id) async {
      final computers = await ref.watch(allDiveComputersProvider.future);
      for (final computer in computers) {
        if (computer.id == id) {
          return duplicateCandidatesFor(computer, computers);
        }
      }
      return const [];
    });

/// Get the favorite (primary) dive computer
final favoriteDiveComputerProvider = FutureProvider<DiveComputer?>((ref) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchComputersChanges());
  return repository.getFavoriteComputer(diverId: validatedDiverId);
});

/// Get dive computers for a specific dive
final computersForDiveProvider =
    FutureProvider.family<List<DiveComputer>, String>((ref, diveId) async {
      final repository = ref.watch(diveComputerRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return repository.getComputersForDive(diveId);
    });

/// State notifier for managing dive computers
class DiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>> {
  final DiveComputerRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  DiveComputerNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    logFailure(
      _initializeAndLoad(),
      DiveComputerNotifier,
      'initialize and load',
    );

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allDiveComputersProvider);
        logFailure(
          _initializeAndLoad(),
          DiveComputerNotifier,
          'initialize and load',
        );
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _load();
  }

  Future<void> _load() async {
    try {
      final computers = await _repository.getAllComputers(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(computers);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _load();
    _ref.invalidate(allDiveComputersProvider);
    _ref.invalidate(favoriteDiveComputerProvider);
  }

  Future<DiveComputer> create(DiveComputer computer) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final computerWithDiver = validatedId != null
        ? computer.copyWith(diverId: validatedId)
        : computer;
    final created = await _repository.createComputer(computerWithDiver);
    await _load();
    _ref.invalidate(allDiveComputersProvider);
    return created;
  }

  Future<void> update(DiveComputer computer) async {
    await _repository.updateComputer(computer);
    await _load();
    _ref.invalidate(allDiveComputersProvider);
    _ref.invalidate(favoriteDiveComputerProvider);
    _ref.invalidate(diveComputerByIdProvider(computer.id));
  }

  Future<void> delete(String id) async {
    await _repository.deleteComputer(id);
    // The installation-local clock sync keys for this computer would
    // otherwise outlive it in SharedPreferences (issue #1216).
    await _ref.read(clockSyncSettingsNotifierProvider.notifier).forget(id);
    await _load();
    _ref.invalidate(allDiveComputersProvider);
    _ref.invalidate(favoriteDiveComputerProvider);
    _ref.invalidate(diveComputerByIdProvider(id));
  }

  Future<void> setFavorite(String id) async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    await _repository.setFavoriteComputer(id, diverId: validatedId);
    await _load();
  }

  /// Folds [duplicateIds] into [survivorId] and refreshes every computer
  /// provider. Dive-side providers are the caller's to invalidate: this file
  /// is imported by the dive providers, so it cannot import them back.
  Future<DiveComputerMergeResult> merge({
    required String survivorId,
    required List<String> duplicateIds,
  }) async {
    final result = await _ref
        .read(diveComputerMergeRepositoryProvider)
        .mergeComputers(survivorId: survivorId, duplicateIds: duplicateIds);
    await _load();
    _ref.invalidate(allDiveComputersProvider);
    _ref.invalidate(favoriteDiveComputerProvider);
    _ref.invalidate(possibleDuplicateComputersProvider);
    _ref.invalidate(computersForDiveProvider);
    _ref.invalidate(diveComputerByIdProvider(survivorId));
    for (final id in result.mergedComputerIds) {
      _ref.invalidate(diveComputerByIdProvider(id));
    }
    return result;
  }
}

/// Provider for dive computer management
final diveComputerNotifierProvider =
    StateNotifierProvider<DiveComputerNotifier, AsyncValue<List<DiveComputer>>>(
      (ref) {
        final repository = ref.watch(diveComputerRepositoryProvider);
        return DiveComputerNotifier(repository, ref);
      },
    );
