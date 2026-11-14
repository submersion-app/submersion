import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// Turns an equipment set into what it applies, and holds the rules about
/// sets that include sets (issue #4525).
///
/// Pure: every lookup is handed in. Reading is tolerant of data the write
/// rules forbid, because two devices can each make a valid edit that
/// together break them: expansion goes exactly one level and skips ids it
/// cannot find, so it cannot loop and never throws.
abstract final class SetBundleResolver {
  /// The sets [set] includes that can be found, in order, leaving out [set]
  /// itself.
  static List<EquipmentSet> _included(
    EquipmentSet set,
    Map<String, EquipmentSet> setsById,
  ) => [
    for (final id in set.includedSetIds)
      if (id != set.id) ?setsById[id],
  ];

  /// [set]'s gear with what the sets it includes contribute first, without
  /// duplicates.
  static List<String> effectiveGearIds(
    EquipmentSet set,
    Map<String, EquipmentSet> setsById,
  ) {
    final seen = <String>{};
    return [
      for (final part in [..._included(set, setsById), set])
        for (final id in part.equipmentIds)
          if (seen.add(id)) id,
    ];
  }

  /// Everything applying [set] puts on a dive. Included sets come first,
  /// then the set's own lists; a preset or configuration reached twice
  /// counts twice.
  static SetBundle resolve(
    EquipmentSet set, {
    required Map<String, EquipmentSet> setsById,
    required Map<String, WeightPreset> presetsById,
    required Map<String, CylinderConfig> configsById,
  }) {
    final parts = [..._included(set, setsById), set];
    final weights = <WeightEntryDraft>[
      for (final part in parts)
        for (final presetId in part.weightPresetIds)
          for (final entry
              in presetsById[presetId]?.entries ?? const <WeightPresetEntry>[])
            (
              weightType: entry.weightType,
              amountKg: entry.amountKg,
              notes: entry.notes,
              label: entry.label,
            ),
    ];
    final joined = <CylinderConfigItem>[
      for (final part in parts)
        for (final configId in part.cylinderConfigIds)
          ..._inOrder(configsById[configId]),
    ];
    return SetBundle(
      setId: set.id,
      gearIds: effectiveGearIds(set, setsById),
      weights: weights,
      // CylinderConfigApplier sorts by each cylinder's own position, which
      // would interleave two configurations that both start at zero.
      cylinders: [
        for (final (i, item) in joined.indexed) item.copyWith(sortOrder: i),
      ],
    );
  }

  static List<CylinderConfigItem> _inOrder(CylinderConfig? config) {
    if (config == null) return const [];
    return [...config.items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// [landing] without the sets that another set in the list includes: an
  /// outer set absorbs the sets it includes, so their lead and cylinders
  /// count once. Order is kept.
  static List<EquipmentSet> absorb(List<EquipmentSet> landing) {
    final absorbed = <String>{
      for (final set in landing)
        for (final id in set.includedSetIds)
          if (id != set.id) id,
    };
    return [
      for (final set in landing)
        if (!absorbed.contains(set.id)) set,
    ];
  }

  /// The sets among [allSets] that include [setId].
  static List<EquipmentSet> outerSetsOf(
    String setId,
    Iterable<EquipmentSet> allSets,
  ) => [
    for (final set in allSets)
      if (set.id != setId && set.includedSetIds.contains(setId)) set,
  ];

  /// Whether [outer] may include [candidate]. Nesting is one level deep: a
  /// set cannot include itself, a set that has includes, or anything once
  /// another set includes [outer]; and both belong to one diver.
  static bool canInclude(
    EquipmentSet outer,
    EquipmentSet candidate,
    Iterable<EquipmentSet> allSets,
  ) {
    if (candidate.id == outer.id) return false;
    if (candidate.diverId != outer.diverId) return false;
    if (candidate.includedSetIds.isNotEmpty) return false;
    return outerSetsOf(outer.id, allSets).isEmpty;
  }

  /// Whether a dive's weights are still exactly what a bundle filled in:
  /// the same entries in the same order, ids aside.
  static bool sameWeights(
    List<DiveWeight> onDive,
    List<WeightEntryDraft> fromBundle,
  ) {
    if (onDive.length != fromBundle.length) return false;
    for (var i = 0; i < onDive.length; i++) {
      final a = onDive[i];
      final b = fromBundle[i];
      if (a.weightType != b.weightType ||
          a.label != b.label ||
          a.notes != b.notes ||
          (a.amountKg - b.amountKg).abs() > 1e-6) {
        return false;
      }
    }
    return true;
  }
}
