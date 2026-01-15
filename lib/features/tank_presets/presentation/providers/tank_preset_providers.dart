import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Repository provider
final tankPresetRepositoryProvider = Provider<TankPresetRepository>((ref) {
  return TankPresetRepository();
});

/// All tank presets provider (custom + built-in, custom first)
/// Includes built-in presets plus custom presets for the current diver
final tankPresetsProvider = FutureProvider<List<TankPresetEntity>>((ref) async {
  final repository = ref.watch(tankPresetRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllPresets(diverId: validatedDiverId);
});

/// Custom (user-defined) tank presets only for the current diver
final customTankPresetsProvider = FutureProvider<List<TankPresetEntity>>((
  ref,
) async {
  final repository = ref.watch(tankPresetRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getCustomPresets(diverId: validatedDiverId);
});

/// Single tank preset provider
final tankPresetProvider = FutureProvider.family<TankPresetEntity?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(tankPresetRepositoryProvider);
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
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        // Immediately set state to loading to prevent showing stale data
        state = const AsyncValue.loading();

        // Invalidate the validated provider to ensure fresh data
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(tankPresetsProvider);
        _ref.invalidate(customTankPresetsProvider);
        _initializeAndLoad();
      }
    });
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
