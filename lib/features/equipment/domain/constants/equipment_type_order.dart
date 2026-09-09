import 'package:submersion/core/constants/enums.dart';

/// How a gear list orders equipment types.
///
/// This is the primary key of an `EquipmentArrangement`: it orders the group
/// headers when the diver groups by type, and acts as the primary sort key
/// when they do not.
enum EquipmentTypeOrder {
  /// Ignore type entirely; the item sort orders the whole flat list.
  none,

  /// By the type's localized label, so the answer follows the locale.
  alphabetical,

  /// Roughly how the gear sits on a diver, top down.
  headToToe,

  /// The order the gear actually goes on.
  dressingOrder,

  /// Grouped by function: life support, buoyancy, exposure, vision and
  /// propulsion, instruments, accessories.
  canonical,
}

/// Head to toe, following the sequence requested in #1576.
///
/// Ordered lists rather than rank maps on purpose: a list can be asserted to
/// be an exact permutation of [EquipmentType.values], so adding a type breaks
/// the suite instead of silently ranking the newcomer last.
const List<EquipmentType> kHeadToToeTypeOrder = [
  EquipmentType.hood,
  EquipmentType.mask,
  EquipmentType.snorkel,
  EquipmentType.rashGuard,
  EquipmentType.baselayer,
  EquipmentType.undersuit,
  EquipmentType.wetsuit,
  EquipmentType.drysuit,
  EquipmentType.tank,
  EquipmentType.rebreather,
  EquipmentType.regulator,
  // Assembly parts (#1487) sit beside the item they are part of.
  EquipmentType.firstStage,
  EquipmentType.secondStage,
  EquipmentType.hose,
  EquipmentType.transmitter,
  EquipmentType.bcd,
  EquipmentType.backplate,
  EquipmentType.wing,
  EquipmentType.harness,
  EquipmentType.weights,
  EquipmentType.computer,
  EquipmentType.instrument,
  EquipmentType.compass,
  EquipmentType.light,
  EquipmentType.camera,
  EquipmentType.housing,
  EquipmentType.strobe,
  EquipmentType.smb,
  EquipmentType.reel,
  EquipmentType.knife,
  EquipmentType.tool,
  EquipmentType.dpv,
  EquipmentType.gloves,
  EquipmentType.boots,
  EquipmentType.fins,
  // Consumable child parts (#1708): they live inside another item and are
  // never worn or donned on their own, so they have no position in an
  // anatomical or a dressing sequence. They tail the list beside `other`
  // rather than being guessed next to a likely host, since a battery serves
  // computers, lights and transmitters alike.
  EquipmentType.o2Cell,
  EquipmentType.battery,
  EquipmentType.other,
];

/// The order gear goes on, per #1576.
///
/// The issue does not place the hood. It sits after boots and before the
/// cylinder, which is when a wetsuit diver pulls it on.
const List<EquipmentType> kDressingTypeOrder = [
  EquipmentType.rashGuard,
  EquipmentType.baselayer,
  EquipmentType.undersuit,
  EquipmentType.wetsuit,
  EquipmentType.drysuit,
  EquipmentType.boots,
  EquipmentType.hood,
  EquipmentType.weights,
  EquipmentType.tank,
  EquipmentType.rebreather,
  EquipmentType.regulator,
  // Assembly parts (#1487) sit beside the item they are part of.
  EquipmentType.firstStage,
  EquipmentType.secondStage,
  EquipmentType.hose,
  EquipmentType.transmitter,
  EquipmentType.bcd,
  EquipmentType.backplate,
  EquipmentType.wing,
  EquipmentType.harness,
  EquipmentType.computer,
  EquipmentType.instrument,
  EquipmentType.compass,
  EquipmentType.light,
  EquipmentType.camera,
  EquipmentType.housing,
  EquipmentType.strobe,
  EquipmentType.smb,
  EquipmentType.reel,
  EquipmentType.knife,
  EquipmentType.tool,
  EquipmentType.dpv,
  EquipmentType.fins,
  EquipmentType.mask,
  EquipmentType.snorkel,
  EquipmentType.gloves,
  // Consumable child parts (#1708): they live inside another item and are
  // never worn or donned on their own, so they have no position in an
  // anatomical or a dressing sequence. They tail the list beside `other`
  // rather than being guessed next to a likely host, since a battery serves
  // computers, lights and transmitters alike.
  EquipmentType.o2Cell,
  EquipmentType.battery,
  EquipmentType.other,
];

/// Grouped by function.
///
/// This is also the honest replacement for `EquipmentType.index`, whose order
/// is an artifact of when each type was added rather than a design (see the
/// #1537 and #1518 comments in `enums.dart`).
const List<EquipmentType> kCanonicalTypeOrder = [
  // Life support.
  EquipmentType.regulator,
  // Assembly parts (#1487) sit beside the item they are part of.
  EquipmentType.firstStage,
  EquipmentType.secondStage,
  EquipmentType.hose,
  EquipmentType.rebreather,
  EquipmentType.tank,
  EquipmentType.transmitter,
  // Buoyancy and trim.
  EquipmentType.bcd,
  EquipmentType.backplate,
  EquipmentType.wing,
  EquipmentType.harness,
  EquipmentType.weights,
  // Exposure protection.
  EquipmentType.rashGuard,
  EquipmentType.baselayer,
  EquipmentType.undersuit,
  EquipmentType.wetsuit,
  EquipmentType.drysuit,
  EquipmentType.hood,
  EquipmentType.gloves,
  EquipmentType.boots,
  // Vision and propulsion.
  EquipmentType.mask,
  EquipmentType.snorkel,
  EquipmentType.fins,
  EquipmentType.dpv,
  // Instruments.
  EquipmentType.computer,
  EquipmentType.instrument,
  EquipmentType.compass,
  // Accessories.
  EquipmentType.light,
  EquipmentType.camera,
  EquipmentType.housing,
  EquipmentType.strobe,
  EquipmentType.smb,
  EquipmentType.reel,
  EquipmentType.knife,
  EquipmentType.tool,
  // Consumable child parts (#1708), a family of their own: they live inside
  // another item rather than being gear a diver wears.
  EquipmentType.o2Cell,
  EquipmentType.battery,
  EquipmentType.other,
];

/// The rank table for [order], or null when the order needs no table.
///
/// [EquipmentTypeOrder.alphabetical] has no table because the correct answer
/// depends on the locale and is computed from the type's label at call time.
List<EquipmentType>? equipmentTypeRankTable(EquipmentTypeOrder order) =>
    switch (order) {
      EquipmentTypeOrder.none => null,
      EquipmentTypeOrder.alphabetical => null,
      EquipmentTypeOrder.headToToe => kHeadToToeTypeOrder,
      EquipmentTypeOrder.dressingOrder => kDressingTypeOrder,
      EquipmentTypeOrder.canonical => kCanonicalTypeOrder,
    };

/// Position of [type] in [table].
///
/// A type absent from the table sorts last rather than throwing. The
/// permutation test makes that unreachable, but a released build should
/// degrade rather than crash a dive's gear list.
int equipmentTypeRank(EquipmentType type, List<EquipmentType> table) {
  final index = table.indexOf(type);
  return index == -1 ? table.length : index;
}
