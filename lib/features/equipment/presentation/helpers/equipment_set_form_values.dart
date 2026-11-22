import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

/// [set]'s own members the diver can no longer see (a share was removed,
/// issue #2046), for the set editor to list without a checkbox.
///
/// [EquipmentSet.items] is what the set applies, the gear of the sets it
/// includes too (issue #4525), so it is narrowed to the set's own members:
/// an included set's hidden item is that set's to show. None until
/// [visibleIds] has loaded, and none for a new set.
List<EquipmentItem> unsharedSetMembers(
  EquipmentSet? set,
  Set<String>? visibleIds,
) {
  if (set == null || visibleIds == null) return const [];
  final own = set.equipmentIds.toSet();
  return [
    for (final item in set.items ?? const <EquipmentItem>[])
      if (own.contains(item.id) && !visibleIds.contains(item.id)) item,
  ];
}

/// The three ordered lists a set carries besides its gear (issue #4525):
/// the sets it includes, its weight presets and its cylinder configurations.
/// Order matters, so a reorder is a change.
class SetBundleListValues extends Equatable {
  final List<String> includedSetIds;
  final List<String> weightPresetIds;
  final List<String> cylinderConfigIds;

  const SetBundleListValues({
    this.includedSetIds = const [],
    this.weightPresetIds = const [],
    this.cylinderConfigIds = const [],
  });

  static const empty = SetBundleListValues();

  factory SetBundleListValues.of(EquipmentSet set) => SetBundleListValues(
    includedSetIds: set.includedSetIds,
    weightPresetIds: set.weightPresetIds,
    cylinderConfigIds: set.cylinderConfigIds,
  );

  SetBundleListValues copyWith({
    List<String>? includedSetIds,
    List<String>? weightPresetIds,
    List<String>? cylinderConfigIds,
  }) => SetBundleListValues(
    includedSetIds: includedSetIds ?? this.includedSetIds,
    weightPresetIds: weightPresetIds ?? this.weightPresetIds,
    cylinderConfigIds: cylinderConfigIds ?? this.cylinderConfigIds,
  );

  @override
  List<Object?> get props => [
    includedSetIds,
    weightPresetIds,
    cylinderConfigIds,
  ];
}
