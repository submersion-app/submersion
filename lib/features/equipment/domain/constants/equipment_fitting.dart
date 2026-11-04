import 'package:submersion/core/constants/enums.dart';

/// Types whose detail page shows the children card: the parents a cell
/// or a battery can be installed in. The edit page's parent picker offers
/// a battery exactly this set, so a host the picker allows always shows the
/// battery it holds.
const childHostTypes = {
  EquipmentType.rebreather,
  EquipmentType.computer,
  EquipmentType.transmitter,
  EquipmentType.light,
  EquipmentType.videoLight,
  EquipmentType.dpv,
};

/// Which item types can hold a child of [type]. Empty means the type is
/// not a child type, so an item of it is never fitted to another.
Set<EquipmentType> parentTypesFor(EquipmentType type) => switch (type) {
  EquipmentType.o2Cell => const {EquipmentType.rebreather},
  // The detail page's host set, so a battery is only ever installed where
  // its host's Children card will show it.
  EquipmentType.battery => childHostTypes,
  _ => const {},
};
