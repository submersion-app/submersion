import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

/// Resolves a preset name to a [TankPresetEntity].
///
/// When a repository is available, delegates to [TankPresetRepository.getPresetByName()]
/// which checks the diver's custom presets first, then built-in. This ensures a
/// custom preset that shadows a built-in name is found correctly.
///
/// Without a repository, falls back to built-in presets only.
/// Returns null if the preset name is not found (stale reference).
class DefaultTankPresetResolver {
  final TankPresetRepository? _repository;

  DefaultTankPresetResolver({TankPresetRepository? repository})
    : _repository = repository;

  /// Resolve a preset name to a [TankPresetEntity].
  ///
  /// [diverId] is the diver whose default tank setting names the preset: only
  /// their own custom presets match (issue #3343).
  ///
  /// Returns null if [presetName] is null or the preset cannot be found.
  Future<TankPresetEntity?> resolve(
    String? presetName, {
    required String? diverId,
  }) async {
    if (presetName == null) return null;

    // Delegate to repository (checks custom first, then built-in)
    if (_repository != null) {
      return _repository.getPresetByName(presetName, diverId: diverId);
    }

    // Fallback: built-in presets only (no DB available)
    final builtIn = TankPresets.byName(presetName);
    if (builtIn != null) {
      return TankPresetEntity.fromBuiltIn(builtIn);
    }

    return null;
  }
}
