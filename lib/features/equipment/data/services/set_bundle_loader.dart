import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// Loads what equipment sets apply (issue #4525): reads the sets, the sets
/// they include, and the weight presets and cylinder configurations they
/// name, and resolves each into a [SetBundle].
class SetBundleLoader {
  SetBundleLoader({
    EquipmentSetRepository? sets,
    WeightPresetRepository? presets,
    CylinderConfigRepository? configs,
  }) : _sets = sets ?? EquipmentSetRepository(),
       _presets = presets ?? WeightPresetRepository(),
       _configs = configs ?? CylinderConfigRepository();

  final EquipmentSetRepository _sets;
  final WeightPresetRepository _presets;
  final CylinderConfigRepository _configs;

  /// The bundles of [setIds], in the order given. A set another requested
  /// set includes is absorbed into it, so its lead and cylinders count once;
  /// an id with no set is skipped.
  Future<List<SetBundle>> load(List<String> setIds) async {
    final wanted = setIds.toSet().toList();
    if (wanted.isEmpty) return const [];
    final requested = await _sets.getAllSets(ids: wanted);
    if (requested.isEmpty) return const [];
    final setsById = {for (final set in requested) set.id: set};

    final includedIds = {for (final set in requested) ...set.includedSetIds}
      ..removeAll(setsById.keys);
    if (includedIds.isNotEmpty) {
      for (final set in await _sets.getAllSets(ids: includedIds.toList())) {
        setsById[set.id] = set;
      }
    }

    final presetsById = <String, WeightPreset>{};
    final configsById = <String, CylinderConfig>{};
    for (final set in setsById.values) {
      for (final id in set.weightPresetIds) {
        if (presetsById.containsKey(id)) continue;
        final preset = await _presets.getPresetById(id);
        if (preset != null) presetsById[id] = preset;
      }
      for (final id in set.cylinderConfigIds) {
        if (configsById.containsKey(id)) continue;
        final config = await _configs.getConfigById(id);
        if (config != null) configsById[id] = config;
      }
    }

    final landing = SetBundleResolver.absorb(<EquipmentSet>[
      for (final id in wanted) ?setsById[id],
    ]);
    return [
      for (final set in landing)
        SetBundleResolver.resolve(
          set,
          setsById: setsById,
          presetsById: presetsById,
          configsById: configsById,
        ),
    ];
  }

  /// The bundle of one set, or null when the set is gone.
  Future<SetBundle?> loadOne(String setId) async =>
      (await load([setId])).firstOrNull;
}
