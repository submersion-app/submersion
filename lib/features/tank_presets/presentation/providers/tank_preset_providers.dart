import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/tank_preset_visibility.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Repository provider
final tankPresetRepositoryProvider = Provider<TankPresetRepository>((ref) {
  return TankPresetRepository();
});

/// Tank presets the pickers offer (custom + built-in, custom first)
/// Includes built-in presets plus custom presets for the current diver,
/// minus the built-in presets the diver hid (issue #2305). The Tank Presets
/// settings page reads [tankPresetListNotifierProvider] instead, which keeps
/// every preset so a hidden one can be shown again.
///
/// Stays a [FutureProvider] so imperative
/// `ref.read(tankPresetsProvider.future)` reads still resolve, while
/// self-invalidating whenever the `tank_presets` table changes -- including
/// when a sync applies remote changes -- so list UIs refresh instead of serving
/// a cached one-shot snapshot.
final tankPresetsProvider = FutureProvider<List<TankPresetEntity>>((ref) async {
  final repository = ref.watch(tankPresetRepositoryProvider);
  // Selects the presets that are effectively hidden (the default is always
  // offered), by content rather than by Set instance: a settings reload
  // decodes a fresh Set, and starring a preset that was never hidden must
  // not re-run this provider either.
  final hidden = ref
      .watch(settingsProvider.select(_effectivelyHiddenKey))
      .split('\n')
      .where((name) => name.isNotEmpty)
      .toSet();
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchTankPresetsChanges());
  final all = await repository.getAllPresets(diverId: validatedDiverId);
  return visibleTankPresets(all, hidden);
});

/// The hidden built-in preset slugs minus the default preset, sorted and
/// newline-joined so equal contents compare equal.
String _effectivelyHiddenKey(AppSettings settings) =>
    (settings.hiddenTankPresetIds
            .where((name) => name != settings.defaultTankPreset)
            .toList()
          ..sort())
        .join('\n');

/// Custom (user-defined) tank presets only for the current diver
final customTankPresetsProvider = FutureProvider<List<TankPresetEntity>>((
  ref,
) async {
  final repository = ref.watch(tankPresetRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchTankPresetsChanges());
  return repository.getCustomPresets(diverId: validatedDiverId);
});

/// Single tank preset provider
final tankPresetProvider = FutureProvider.family<TankPresetEntity?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(tankPresetRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTankPresetsChanges());
  return repository.getPresetById(id);
});

/// Tank preset list notifier for mutations
class TankPresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>> {
  final TankPresetRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  TankPresetListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    logFailure(
      _initializeAndLoad(),
      TankPresetListNotifier,
      'initialize and load',
    );

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        // Immediately set state to loading to prevent showing stale data
        state = const AsyncValue.loading();

        // Invalidate the validated provider to ensure fresh data
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(tankPresetsProvider);
        _ref.invalidate(customTankPresetsProvider);
        logFailure(
          _initializeAndLoad(),
          TankPresetListNotifier,
          'initialize and load',
        );
      }
    });

    // Refresh when the tank_presets table changes (e.g. a sync writes rows
    // directly). Cancelled on dispose (provider is autoDispose).
    final tableChangeSub = _repository.watchTankPresetsChanges().listen(
      (_) => _silentReloadPresets(),
    );
    _ref.onDispose(tableChangeSub.cancel);
  }

  Future<void> _initializeAndLoad() async {
    // Get validated diver ID (falls back to default if current doesn't exist)
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadPresets();
  }

  Future<void> _loadPresets() async {
    state = const AsyncValue.loading();
    try {
      final presets = await _repository.getAllPresets(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(presets);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reload without flipping to a loading state, so table-driven refreshes
  /// (e.g. after a sync write) do not flash a spinner over existing data.
  /// Resolves the validated diver id first so a tick arriving before
  /// initialization completes still scopes the query correctly (otherwise a
  /// null diver id would drop custom presets).
  Future<void> _silentReloadPresets() async {
    try {
      _validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final presets = await _repository.getAllPresets(
        diverId: _validatedDiverId,
      );
      if (mounted) state = AsyncValue.data(presets);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadPresets();
    _ref.invalidate(tankPresetsProvider);
  }

  /// Add a new custom tank preset
  Future<TankPresetEntity> addPreset(TankPresetEntity preset) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final presetWithDiver = validatedId != null
        ? preset.copyWith(diverId: validatedId)
        : preset;
    final newPreset = await _repository.createPreset(presetWithDiver);
    await _loadPresets();
    _ref.invalidate(tankPresetsProvider);
    _ref.invalidate(customTankPresetsProvider);
    return newPreset;
  }

  /// Update an existing custom tank preset
  Future<void> updatePreset(TankPresetEntity preset) async {
    await _repository.updatePreset(preset);
    await _loadPresets();
    _ref.invalidate(tankPresetsProvider);
    _ref.invalidate(customTankPresetsProvider);
  }

  /// Delete a custom tank preset (built-in presets cannot be deleted)
  Future<void> deletePreset(String id) async {
    await _repository.deletePreset(id);
    await _loadPresets();
    _ref.invalidate(tankPresetsProvider);
    _ref.invalidate(customTankPresetsProvider);
  }
}

final tankPresetListNotifierProvider =
    StateNotifierProvider.autoDispose<
      TankPresetListNotifier,
      AsyncValue<List<TankPresetEntity>>
    >((ref) {
      final repository = ref.watch(tankPresetRepositoryProvider);
      // Watch the current diver ID so the provider rebuilds when it changes
      ref.watch(currentDiverIdProvider);
      return TankPresetListNotifier(repository, ref);
    });
