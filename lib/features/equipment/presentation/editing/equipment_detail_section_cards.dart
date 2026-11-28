import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/equipment_detail_sections.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_fitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';

/// The card each section of a gear item's page edits in place, for the
/// sections that have one (issue #4975). A hidden section with a card still
/// reaches the unlocked page through the add strip; the others only show
/// what the page calculates or opens elsewhere, so hiding them hides them.
const Map<EquipmentDetailSectionId, GearItemCardId>
equipmentDetailSectionCards = {
  EquipmentDetailSectionId.diveComputer: GearItemCardId.diveComputer,
  EquipmentDetailSectionId.details: GearItemCardId.details,
  EquipmentDetailSectionId.location: GearItemCardId.location,
  EquipmentDetailSectionId.twinSet: GearItemCardId.twinSet,
  EquipmentDetailSectionId.serviceClocks: GearItemCardId.serviceClocks,
  EquipmentDetailSectionId.condition: GearItemCardId.conditionFindings,
  EquipmentDetailSectionId.photos: GearItemCardId.photos,
  EquipmentDetailSectionId.observations: GearItemCardId.observations,
  EquipmentDetailSectionId.components: GearItemCardId.components,
  EquipmentDetailSectionId.linkedFiles: GearItemCardId.legacyFiles,
  EquipmentDetailSectionId.serviceHistory: GearItemCardId.serviceHistory,
  EquipmentDetailSectionId.notes: GearItemCardId.notes,
  EquipmentDetailSectionId.documents: GearItemCardId.documents,
};

/// The sections an item not yet created shows: the cards of its own values.
/// What reads the stored item by its id waits until it exists (plan 11).
const Set<EquipmentDetailSectionId> _newItemSections = {
  EquipmentDetailSectionId.details,
  EquipmentDetailSectionId.location,
  EquipmentDetailSectionId.serviceClocks,
  EquipmentDetailSectionId.notes,
  EquipmentDetailSectionId.documents,
};

/// Whether section [id] belongs on [item]'s page at all, whatever the
/// diver's visibility setting: a dive computer's controls only on a
/// computer, a twin set only on a cylinder. [creating] is an item not yet
/// stored; [multipleDivers] is whether there are two or more profiles.
bool equipmentDetailSectionApplies(
  EquipmentDetailSectionId id,
  EquipmentItem item, {
  required bool creating,
  required bool multipleDivers,
}) {
  if (creating && !_newItemSections.contains(id)) return false;
  return switch (id) {
    EquipmentDetailSectionId.diveComputer =>
      item.type == EquipmentType.computer,
    EquipmentDetailSectionId.transmitter =>
      item.type == EquipmentType.transmitter,
    EquipmentDetailSectionId.passport =>
      item.type == EquipmentType.tank || !item.isWanted,
    EquipmentDetailSectionId.twinSet => item.type == EquipmentType.tank,
    // Wishlist gear (#2025) is out of service clocks.
    EquipmentDetailSectionId.serviceClocks => !item.isWanted,
    EquipmentDetailSectionId.childItems => childHostTypes.contains(item.type),
    EquipmentDetailSectionId.unitConfigurations =>
      item.type == EquipmentType.rebreather,
    EquipmentDetailSectionId.sharingHistory => multipleDivers,
    EquipmentDetailSectionId.details ||
    EquipmentDetailSectionId.location ||
    EquipmentDetailSectionId.exposure ||
    EquipmentDetailSectionId.condition ||
    EquipmentDetailSectionId.photos ||
    EquipmentDetailSectionId.observations ||
    EquipmentDetailSectionId.components ||
    EquipmentDetailSectionId.linkedFiles ||
    EquipmentDetailSectionId.serviceHistory ||
    EquipmentDetailSectionId.notes ||
    EquipmentDetailSectionId.documents => true,
  };
}
