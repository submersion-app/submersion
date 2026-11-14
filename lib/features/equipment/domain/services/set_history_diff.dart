import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';

/// The rewrites one set's dives need after a save.
typedef SetHistoryChange = ({String setId, List<SetHistoryRewrite> rewrites});

/// What saving a set changes about the gear dives carry (issues #4283,
/// #4525): [before] is the set as it was, [after] as saved, [allSets] every
/// set of the diver before the save.
///
/// A set applies its own gear plus that of the sets it includes, and a dive
/// tags that gear with the set that was picked. So the edited set's dives
/// follow its effective gear, and so do the dives of every set that
/// includes it. The edited set comes first; sets whose gear did not change
/// are left out. Weight presets and cylinder configurations are copied onto
/// a dive and never rewritten, so a change to those gives nothing.
List<SetHistoryChange> setHistoryRewrites({
  required EquipmentSet before,
  required EquipmentSet after,
  required Iterable<EquipmentSet> allSets,
}) {
  final beforeById = {for (final s in allSets) s.id: s, before.id: before};
  final afterById = {...beforeById, after.id: after};
  final changes = <SetHistoryChange>[];
  for (final target in [
    after,
    ...SetBundleResolver.outerSetsOf(after.id, allSets),
  ]) {
    final was = SetBundleResolver.effectiveGearIds(
      beforeById[target.id]!,
      beforeById,
    ).toSet();
    final now = SetBundleResolver.effectiveGearIds(
      afterById[target.id]!,
      afterById,
    ).toSet();
    final rewrites = <SetHistoryRewrite>[
      for (final id in now.difference(was)) SetItemAdded(id),
      for (final id in was.difference(now)) SetItemRemoved(id),
    ];
    if (rewrites.isNotEmpty) {
      changes.add((setId: target.id, rewrites: rewrites));
    }
  }
  return changes;
}
